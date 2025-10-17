# Scheduling Screen Debug Instructions

## Issue
Scheduling screen shows no data after POS transactions.

## What I've Done

### 1. ✅ Fixed Field Name Issues
- **File:** `pos_screen.dart` line 2120
- Changed `selectedDateTime` → `scheduledDateTime`
- Changed `total` → `totalAmount`

### 2. ✅ Added Fallback Query
- **File:** `booking_data_unified.dart` line 365-407
- Added try-catch to handle missing Firestore index
- Falls back to in-memory filtering if composite query fails

### 3. ✅ Added Comprehensive Debug Logging
- **Scheduling Screen** logs:
  - Total bookings loaded
  - Each booking's status, user, source, and date
  - Count by status (pending, approved, completed, cancelled)

- **Debug Check** logs:
  - First 5 bookings in database
  - Which datetime field they have (scheduledDateTime vs selectedDateTime)
  - Status, source, userName

## How to Debug

### Step 1: Run the App and Check Console
```bash
flutter run -d linux
```

### Step 2: Navigate to Scheduling Screen
Look for these debug messages in console:

```
🔍 DEBUG: Total bookings in Firestore: X
  📄 Booking [id]:
    - hasScheduledDateTime: true/false
    - hasSelectedDateTime: true/false
    - status: approved/pending
    - source: pos/customer-app
```

### Step 3: Check Query Results
```
🔍 Loading bookings with filter: today
📊 Total bookings loaded: X
  - approved: Customer Name (pos) - 2025-10-16 14:30
✅ Pending: 0, Approved: X, Completed: 0, Cancelled: 0
```

## Common Issues & Solutions

### Issue 1: "Total bookings loaded: 0"
**Possible Causes:**
1. No bookings exist in database for today
2. Old bookings have `selectedDateTime` instead of `scheduledDateTime`
3. Firestore composite index missing AND fallback query failing

**Solution:**
- Create a NEW POS transaction to test
- Check debug output to see which datetime field exists
- If old bookings have `selectedDateTime`, they won't show until migrated

### Issue 2: "DEBUG: Total bookings: 5 but Total loaded: 0"
**Cause:** All bookings have wrong datetime field

**Solution:** Old bookings need field migration:
```dart
// Migration script needed to update existing bookings
// Update selectedDateTime → scheduledDateTime
```

### Issue 3: Firestore Index Error
**Error Message:** "requires an index"

**Solution:**
The code now has a fallback that should handle this automatically.
If you see this error, click the provided link to create the index in Firebase Console.

## What to Tell Me

Please run the app and share:

1. **Console output** showing:
   - 🔍 DEBUG messages
   - 📊 Total bookings loaded
   - ✅ Status counts

2. **Screenshot** of the scheduling screen

3. **Answer these questions:**
   - Did you create a NEW POS transaction today?
   - Do you see any bookings in the debug output?
   - What's the date/time shown for those bookings?
   - Are the bookings from today or old bookings?

## Quick Test

### Create a Fresh POS Transaction:
1. Go to POS screen
2. Add customer (any name/plate)
3. Add a service
4. Select team
5. Complete payment
6. Check console for: `📄 Booking [new-id]`
7. Go to Scheduling screen
8. Should appear in "Approved" column

## Files Modified
- ✅ `pos_screen.dart` - Fixed field names
- ✅ `booking_data_unified.dart` - Added fallback query + logging
- ✅ `scheduling_screen.dart` - Added debug logging
- ✅ `admin_staff_home.dart` - Fixed customer name reading

All changes compile successfully with no errors.
