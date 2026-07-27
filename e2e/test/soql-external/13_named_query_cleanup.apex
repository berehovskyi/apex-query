// 13_named_query_cleanup.apex
List<Account> accounts = [SELECT Id FROM Account WHERE Name LIKE 'Named Query E2E %'];
Database.delete(accounts, false);
Assert.areEqual(2000, accounts.size(), 'Expected to clean every generated Named Query Account');
System.debug('E2E Test 13 Cleanup Passed');
