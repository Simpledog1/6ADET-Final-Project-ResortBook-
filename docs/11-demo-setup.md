# Demo setup

Example data to enter before a live demo, so the dashboard, list and calendar are not empty and the overlap check can be shown. All guests are made up. Enter it in the app under **Manage Resort** and **Add Reservation** (about 5 to 10 minutes).

## Manage Resort

**Unit Types**

| Name | Default capacity |
| --- | --- |
| Cottage | 4 |
| Villa | 6 |

**Stay Types**

| Name | Check-in | Check-out | Ends next day | Multiple nights | Pricing |
| --- | --- | --- | --- | --- | --- |
| Overnight | 2:00 PM | 12:00 PM | Yes | Yes | Per night |
| Day Tour | 8:00 AM | 5:00 PM | No | No | Per stay |
| Night Tour | 7:00 PM | 6:00 AM | Yes | No | Per stay |

**Units**

| Name | Unit type | Capacity |
| --- | --- | --- |
| Cottage A | Cottage | 4 |
| Cottage B | Cottage | 4 |
| Villa 1 | Villa | 6 |

**Rates (₱)**

| | Overnight | Day Tour | Night Tour |
| --- | --- | --- | --- |
| Cottage | 5,000 | 800 | 1,200 |
| Villa | 8,000 | 2,500 | 3,000 |

## Reservations to add beforehand

Book these a few days after the presentation date (2 guests each):

| Guest | Unit | Stay type | Check-in |
| --- | --- | --- | --- |
| Maria Santos | Cottage A | Overnight, 2 nights | presentation day + 2 |
| Ana Reyes | Villa 1 | Overnight, 1 night | presentation day + 1 |
| Juan dela Cruz | Cottage B | Day Tour | presentation day + 3 |

Maria Santos is needed for the conflict demo. The other two fill the dashboard.

## During the live demo

1. **Add a booking:** any made-up guest, 2 guests, **Day Tour**, **Cottage B**, check-in **today**. Show the calculated check-out and total, then save.
2. **Show the conflict:** **Cottage A**, **Overnight**, check-in on the day after Maria Santos checks in. Saving shows **Date Conflict Detected**.
3. **Workflow:** open the booking from step 1, press **Check In**, then **Mark Completed**. Check In only works from the check-in date, which is why that booking is for today.

Do a full run-through the day before, then cancel the test bookings you made so the live steps behave the same on the day.
