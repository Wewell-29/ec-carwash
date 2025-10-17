# Inventory & Expenses Feature Audit

## INVENTORY SCREEN - Requirements Checklist

### ✅ Currently Working:
1. **View History** - ✅ `InventoryLog` system exists (line 224-276 in inventory_data.dart)
2. **History Tracking** - ✅ Logs for withdraw, add, adjust actions
3. **Low Stock Alerts** - ✅ Working (line 24, 87-88 in inventory_screen.dart)
4. **Category Filter** - ✅ Working (line 48-50)

### ❌ MISSING/BROKEN Features:

#### 1. **Add New Inventory Item**
**Status:** EXISTS but needs fixes

**Current Issues:**
- ❌ Category: Free text input (should be dropdown with "Others" option)
- ❌ Unit: Free text input (should be dropdown)
- ⚠️ Unit Price field: EXISTS (should be removed per requirements)

**Files to check:**
- `inventory_screen.dart` - Add item dialog

---

#### 2. **Add New Stock**
**Status:** ❌ NOT WORKING PROPERLY

**Issue:** "Not showing in history (should be adjustable)"

**Current Implementation:**
- ✅ Function exists: `addStockWithLog()` (line 404-426 in inventory_data.dart)
- ❌ Need to verify history is actually saved and displayed

---

#### 3. **Delete Item**
**Status:** ❌ ACTION NOT RECORDED

**Issue:** "Action not recorded in history"

**Current State:**
- `deleteItem()` exists but NO logging
- Need to add log entry before deletion

---

#### 4. **Adjust Stock**
**Status:** ❌ NOT WORKING PROPERLY

**Issues:**
- "Adjustment not working properly"
- ❌ Missing optional Notes field

**Current Implementation:**
- ✅ Function exists: `adjustStockWithLog()` (line 428-450)
- ❌ Need to add Notes parameter to UI
- ❌ Need to verify adjustment logic

---

#### 5. **Withdraw Section**
**Status:** ⚠️ PARTIAL

**Issues:**
- ❌ Quantity field: "Should accept numbers only" (needs validation)

**Current Implementation:**
- ✅ `withdrawStock()` exists (line 378-402)
- ❌ UI validation missing

---

#### 6. **Inventory Log History**
**Status:** ⚠️ WORKING BUT NEEDS FIX

**Issue:** "Text/font size is too small"

**Current Implementation:**
- ✅ `getLogs()` exists (line 363-376)
- ❌ UI font size needs increase

---

## EXPENSES SCREEN - Requirements Checklist

### ✅ Currently Working:
1. **Add Expense** - ✅ Working
2. **View Expenses** - ✅ Working
3. **Filter by Date** - ✅ Working (today, week, month, custom)
4. **Category Filter** - ✅ Working

### ❌ MISSING Features:

#### 1. **Print Data History**
**Status:** ❌ NOT IMPLEMENTED

**Requirement:** "Add Print Data History functionality"

**What's Needed:**
- Print button in expenses screen
- PDF generation for expense history
- Similar to POS receipt printing

---

## UNIFIED DATA CHECK

### Inventory Data Structure:
**File:** `inventory_data.dart`

```dart
class InventoryItem {
  String id, name, category;
  int currentStock, minStock;
  double unitPrice;
  String unit;
  DateTime lastUpdated;
}

class InventoryLog {
  String itemId, itemName, staffName, action;
  int quantity, stockBefore, stockAfter;
  String? notes;
  DateTime timestamp;
}
```

**Status:** ✅ **Self-contained** - Does NOT need to sync with Transactions/Bookings
**Reason:** Inventory is internal resource management, separate from customer transactions

---

### Expenses Data Structure:
**File:** `expense_data.dart` (need to verify)

**Status:** ⚠️ **NEED TO CHECK**
- Is it using unified timestamps?
- Is it properly isolated from Inventory?
- Does it have proper logging?

---

## ISOLATION CHECK

### ❌ CURRENT ISSUE: Expenses and Inventory NOT Properly Isolated

**Problem:** Line 3 in `expenses_screen.dart`:
```dart
import 'package:ec_carwash/data_models/inventory_data.dart';
```

**Why this is wrong:**
- Expenses screen imports inventory data
- These should be completely separate features
- Expenses should NOT depend on inventory

**What should happen:**
1. **Inventory** = Tracks supplies/products (shampoo, wax, etc.)
2. **Expenses** = Tracks money spent (utilities, rent, purchases, etc.)
3. **Separate collections, separate screens, NO cross-dependencies**

---

## SUMMARY OF REQUIRED CHANGES

### HIGH PRIORITY (Broken/Missing):

1. ❌ **Category Dropdown** - Add dropdown with "Others" option in Add Item dialog
2. ❌ **Unit Dropdown** - Add dropdown for units in Add Item dialog
3. ❌ **Remove Unit Price** - Remove from Add Item dialog
4. ❌ **Delete Item Logging** - Add history log when items deleted
5. ❌ **Adjust Stock Notes** - Add optional notes field to adjust dialog
6. ❌ **Withdraw Validation** - Add number-only validation
7. ❌ **Print Expenses** - Implement PDF print for expense history
8. ❌ **Isolate Features** - Remove inventory import from expenses screen

### MEDIUM PRIORITY (UX Improvements):

9. ⚠️ **History Font Size** - Increase font size in inventory log history
10. ⚠️ **Verify Add Stock History** - Test if add stock shows in history

---

## FILES TO MODIFY

1. `lib/screens/Admin/inventory_screen.dart`
   - Add item dialog (category/unit dropdowns, remove unit price)
   - Adjust stock dialog (add notes field)
   - Withdraw dialog (number validation)
   - History display (increase font size)
   - Delete confirmation (add logging)

2. `lib/data_models/inventory_data.dart`
   - Add delete logging function

3. `lib/screens/Admin/expenses_screen.dart`
   - Remove inventory import
   - Add print functionality
   - Ensure isolation

4. `lib/data_models/expense_data.dart`
   - Verify structure is isolated
   - Check if unified timestamps used

---

## NEXT STEPS

1. Remove inventory import from expenses screen
2. Implement all missing inventory features
3. Add print functionality to expenses
4. Test all changes
5. Verify isolation is complete
