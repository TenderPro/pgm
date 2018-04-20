# utils:90_exception

## test_exception

```sql
SELECT utils.exception_test('select now();')
;
```
 exception_test 
----------------
 

## test_without_exception

```sql
SELECT utils.exception_test('select no();')
;
```
                     exception_test                      
---------------------------------------------------------
 SQLSTATE: 42883 EXCEPTION: function no() does not exist

