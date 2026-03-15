# Category Picker: Search + Inline Add

**Date**: 2026-03-15
**Status**: Approved
**Closes**: #101 (partially — add-only, no edit/delete management screen)

## Overview

Enhance `CategoryPickerSheet` with two capabilities:

1. **Search/filter** — a text field that filters the category hierarchy as the user types
2. **Add new category** — an "Add New Category" row at the bottom of the picker that opens a second modal sheet with a creation form

No new routes. No new screens in the navigation graph. Everything happens within modal bottom sheets launched from the transaction edit flow.

## Current State

- `CategoryPickerSheet` is a `DraggableScrollableSheet` (60% initial, 30-90% range)
- Displays 2-level hierarchy: ~16 expense parents with subcategories, ~7 income parents
- Called from `AddEditTransactionScreen._showCategoryPicker()` with a pre-loaded `List<Category>` passed as a parameter
- Returns `CategoryPickerResult` with `id`, `name`, or cleared state
- No search, no creation capability

## Design

### Search

**Location**: `TextField` pinned below the header, above the scrollable category list.

**Filtering logic** (client-side, on the already-loaded Dart list):
- Case-insensitive substring match on `category.name`
- If a **child** matches, its parent is shown for context (even if the parent name doesn't match)
- If a **parent** matches, all its children are shown
- Empty search field = full hierarchy (current behavior)
- Clear (X) button in the `suffixIcon` when non-empty

**Empty state**: When no categories match, show a centered message: "No categories found" with a tappable "Create '[searchTerm]'?" prompt that opens the add form with the name pre-filled.

**Keyboard interaction**: When the search field receives focus, expand the sheet to max height (`DraggableScrollableController.animateTo(1.0)`) to prevent the keyboard from hiding list content.

### Add New Category

**Entry point**: "Add New Category" row pinned at the bottom of the picker sheet, outside the scrollable area. Always visible regardless of scroll position. Styled with a circular "+" icon and accent-colored label.

**Form presentation**: Tapping the row opens a **new `showModalBottomSheet`** on top of the picker (not content replacement). This avoids DraggableScrollableSheet sizing issues and lets the user see the picker behind for context.

**Form fields**:

| Field | Type | Required | Default |
|-------|------|----------|---------|
| Name | TextField | Yes | Empty (or pre-filled from search term) |
| Type | SegmentedButton | Yes | Matches picker's current filter (expense/income) |
| Parent | DropdownButtonFormField | No | "None (top-level)" — lists parents of selected type |

**Validation** (all client-side, before insert):
- Name trimmed, reject if empty
- Name max 50 characters
- Duplicate check: compare `(name.trim().toLowerCase(), parentId, type)` against the loaded category list. Show inline error "Category already exists" if duplicate found.

**Save flow**:
1. User taps "Save & Select"
2. Button disables, shows small `CircularProgressIndicator`
3. `CategoryRepository.insertCategory()` called with:
   - `id`: UUID
   - `name`: trimmed user input
   - `type`: 'expense' or 'income'
   - `parentId`: selected parent ID or null
   - `icon`: `'label'` (default)
   - `color`: `0xFF9E9E9E` (grey) for expense, `0xFF81C784` (green) for income
   - `isSystem`: false
   - `displayOrder`: 999
   - `createdAt`: `DateTime.now().millisecondsSinceEpoch`
   - `updatedAt`: `DateTime.now().millisecondsSinceEpoch`
4. On success: pop both sheets, return `CategoryPickerResult(id: newId, name: newName)` to the transaction edit screen
5. On error: show snackbar with error message, re-enable button

**Cancel**: Pops the add-category sheet, returns to the picker.

### Data Flow Change

The picker currently receives categories as a constructor parameter (`List<Category> categories`). This creates stale data if a category is added.

**Change**: The picker should `ref.watch(allCategoriesProvider)` internally instead of consuming a passed-in list. The caller passes an **optional type** (`String? type` — 'expense', 'income', or null for both) rather than the data. The picker filters internally based on the type parameter. This makes the picker reactive — new categories appear immediately after insert.

When `type` is null (used by the filter sheet and recurring transaction screen), both expense and income categories are shown. The "Add New Category" row is hidden when `type` is null (filter contexts don't need creation), controlled by a `showAddButton` parameter (defaults to `true`).

The picker is currently implemented as a `showCategoryPickerSheet()` function. The builder body needs to be wrapped in a `Consumer` to access `ref.watch`.

## Files Changed

| File | Change |
|------|--------|
| `lib/presentation/shared/widgets/category_picker_sheet.dart` | Search field, filter logic, add-row, keyboard handling, watch providers internally via `Consumer` |
| `lib/presentation/shared/widgets/add_category_sheet.dart` | **New file** — modal form for creating a category |
| `lib/presentation/features/transactions/add_edit_transaction_screen.dart` | Update `_showCategoryPicker()` to pass type instead of pre-loaded list |
| `lib/presentation/features/recurring/add_edit_recurring_screen.dart` | Same caller update — pass `type: null` (shows all categories) |
| `lib/presentation/features/transactions/widgets/filter_bottom_sheet.dart` | Same caller update — pass `type: null`, `showAddButton: false` |
| `lib/presentation/features/settings/auto_categorize_rules_screen.dart` | Same caller update — pass `type: null` |

## Not In Scope

- Category editing or deletion (full management screen — #101)
- Custom icons or colors (separate feature request to be filed)
- Category reordering
- Deep nesting beyond 2 levels
- Search debouncing (60 categories don't need it)
- Database unique constraints (client-side check is sufficient)
- Desktop-specific sheet behavior

## Test Plan

### Unit Tests
- Search filter logic: parent match shows children, child match shows parent, case-insensitive, empty search returns all
- Validation: empty name rejected, whitespace-only rejected, 50+ char rejected, duplicate detected
- New category defaults: correct icon, color, isSystem=false, displayOrder=999

### Widget Tests
- Search field appears and filters list
- Empty search state shows "No categories found" message
- "Add New Category" row visible and tappable
- Add form opens as second modal
- Save button disables during insert
- Successful save closes both sheets with correct result
- Cancel returns to picker
- Error on insert shows snackbar
- Search term pre-fills name in add form from empty state prompt
