# APIMPolicyBenchmarkTest
A small benchmark test for named value parsing

## Highlights
- Mock Delta (max-min) is 1.24ms
- Mock Range (no filter vs min,max) is -0.19 ~ +1.05
- Backend Delta (max-min) is 1.37ms
- Backend Range (no filter vs min,max) is -0.65 ~ 0.72

On avg sum 1ms difference across all approaches

## Mocked Results
| Name                                 | Type             | ID Count | Mocked | Count | Min (ms) | Max (ms) | Avg (ms) |
|--------------------------------------|------------------|----------|--------|-------|----------|----------|----------|
| Mock if   found 100 policy fragment  | Policy Fragment  | 100      | TRUE   | 15000 | 2        | 3        | 2.18     |
| Mock if   found 370 CSV              | CSV Named Value  | 370      | TRUE   | 15000 | 2        | 4        | 2.23     |
| Mock if   found 370 Json             | JSON Named Value | 370      | TRUE   | 15000 | 2        | 3        | 2.26     |
| Only   Mock                          | No Filter        | 0        | TRUE   | 15000 | 2        | 4        | 2.37     |
| Mock if   found 100 CSV              | CSV Named Value  | 100      | TRUE   | 15000 | 2        | 4        | 2.83     |
| Mock if   found 100 Json             | JSON Named Value | 100      | TRUE   | 15000 | 3        | 4        | 3.15     |
| Mock if   found 370 policy fragment  | Policy Fragment  | 370      | TRUE   | 15000 | 3        | 5        | 3.22     |
| Mock if   found 1000 policy fragment | Policy Fragment  | 1000     | TRUE   | 15000 | 2        | 5        | 3.42     |

## Backend Results
| Name                                 | Type             | ID Count | Mocked | Count | Min (ms) | Max (ms) | Avg (ms) |
|--------------------------------------|------------------|----------|--------|-------|----------|----------|----------|
| Mock if   found 100 Json             | JSON Named Value | 100      | FALSE  | 15000 | 7        | 10       | 7.95     |
| Mock if   found 370 Json             | JSON Named Value | 370      | FALSE  | 15000 | 7        | 10       | 8.05     |
| Only   Backend                       | No Filter        | 0        | FALSE  | 15000 | 7        | 11       | 8.6      |
| Mock if   found 100 CSV              | CSV Named Value  | 100      | FALSE  | 15000 | 7        | 11       | 8.76     |
| Mock if   found 100 policy fragment  | Policy Fragment  | 100      | FALSE  | 15000 | 7        | 11       | 8.83     |
| Mock if   found 370 CSV              | CSV Named Value  | 370      | FALSE  | 15000 | 7        | 11       | 8.9      |
| Mock if   found 1000 policy fragment | Policy Fragment  | 1000     | FALSE  | 15000 | 8        | 12       | 9.13     |
| Mock   if found 370 policy fragment  | Policy Fragment  | 370      | FALSE  | 15000 | 8        | 12       | 9.32     |