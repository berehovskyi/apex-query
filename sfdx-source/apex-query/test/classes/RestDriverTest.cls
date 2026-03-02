@IsTest(IsParallel=true)
private class RestDriverTest {
    private static Integer count = 0;

    // <editor-fold desc="QueryEngine">
    @IsTest
    static void should_execute_rest_query() {
        // Arrange
        MockRest mock = new MockRest();
        mock.addResponse(
            '/services/data/v66.0/query/?q=SELECT+Name+FROM+Account',
            '{"totalSize":1, "done":true, "records":[{"attributes":{"type":"Account"}, "Name":"Acme"}]}'
        );
        Test.setMock(HttpCalloutMock.class, mock);

        SoqlQuery q = SoqlQuery.of('Account').field('Name').useRestDriver('MyOrg');

        // Act
        Test.startTest();
        List<SObject> results = q.fetch();
        Test.stopTest();

        // Assert
        Assert.areEqual(1, results.size());
        Assert.areEqual('Acme', results[0].get('Name'));
    }

    @IsTest
    static void should_validate_api_version_format_for_rest_driver() {
        try {
            new SoqlQuery.RestDriver('MyOrg').setApiVersion('66.0');
            Assert.fail('Expected QueryException for invalid API version format');
        } catch (Query.QueryException e) {
            Assert.isTrue(e.getMessage().contains('apiVersion must match vXX.X'));
        }
    }

    @IsTest
    static void should_execute_rest_query_via_tooling_when_enabled() {
        // Arrange
        MockRest mock = new MockRest();
        mock.addResponse(
            '/services/data/v66.0/tooling/query/?q=SELECT+Name+FROM+Account',
            '{"totalSize":1, "done":true, "records":[{"attributes":{"type":"Account"}, "Name":"ToolingAcme"}]}'
        );
        Test.setMock(HttpCalloutMock.class, mock);

        SoqlQuery q = SoqlQuery.of('Account')
            .field('Name')
            .useDriver(new SoqlQuery.RestDriver('MyOrg').useEngine(new SoqlQuery.QueryEngine().useTooling(true)));

        // Act
        Test.startTest();
        List<SObject> results = q.fetch();
        Test.stopTest();

        // Assert
        Assert.areEqual(1, results.size());
        Assert.areEqual('ToolingAcme', results[0].get('Name'));
    }

    // </editor-fold>

    // <editor-fold desc="BulkV2QueryEngine">
    @IsTest
    static void should_execute_bulk_v2_query_into_untyped_map() {
        // Arrange
        Id id1 = fakeId(Account.SObjectType);
        MockRest mock = new MockRest();
        mock.addResponse('/services/data/v66.0/jobs/query', '{"id":"750TEST001"}');
        mock.addResponse('/services/data/v66.0/jobs/query/750TEST001', '{"id":"750TEST001","state":"JobComplete"}');
        mock.addResponse(
            '/services/data/v66.0/jobs/query/750TEST001/results',
            '"Id","Name","Owner.Name"' + '\n' + '"' + id1 + '","Acme","User User"'
        );
        Test.setMock(HttpCalloutMock.class, mock);

        SoqlQuery q = SoqlQuery.of('Account')
            .field('Id')
            .field('Name')
            .field('Owner.Name')
            .useDriver(new SoqlQuery.RestDriver('MyOrg').useEngine(new SoqlQuery.BulkV2QueryEngine()));

        // Act
        Test.startTest();
        List<Object> results = q.fetchInto(List<Map<String, Object>>.class);
        Test.stopTest();

        // Assert
        Assert.areEqual(1, results.size());
        Map<String, Object> row = (Map<String, Object>) results[0];
        Assert.areEqual('Acme', row.get('Name'));
        Assert.isTrue(row.containsKey('attributes'));
        Map<String, Object> owner = (Map<String, Object>) row.get('Owner');
        Assert.areEqual('User User', owner.get('Name'));
        Assert.isTrue(owner.containsKey('attributes'));
    }

    @IsTest
    static void should_use_bulk_status_object_as_root_type() {
        // Arrange
        MockRest mock = new MockRest();
        mock.addResponse('/services/data/v66.0/jobs/query', '{"id":"750TEST001B"}');
        mock.addResponse(
            '/services/data/v66.0/jobs/query/750TEST001B',
            '{"id":"750TEST001B","state":"JobComplete","object":"Contact"}'
        );
        mock.addResponse('/services/data/v66.0/jobs/query/750TEST001B/results', '"Id","Name"' + '\n' + '"003A","John"');
        Test.setMock(HttpCalloutMock.class, mock);

        SoqlQuery q = SoqlQuery.of('Account')
            .field('Id')
            .field('Name')
            .useDriver(new SoqlQuery.RestDriver('MyOrg').useEngine(new SoqlQuery.BulkV2QueryEngine()));

        // Act
        Test.startTest();
        List<Object> results = q.fetchInto(List<Map<String, Object>>.class);
        Test.stopTest();

        // Assert
        Assert.areEqual(1, results.size());
        Map<String, Object> row = (Map<String, Object>) results[0];
        Map<String, Object> attrs = (Map<String, Object>) row.get('attributes');
        Assert.areEqual('Contact', attrs.get('type'));
    }

    @IsTest
    static void should_execute_bulk_v2_query_into_sobject() {
        // Arrange
        MockRest mock = new MockRest();
        mock.addResponse('/services/data/v66.0/jobs/query', '{"id":"750TEST002"}');
        mock.addResponse('/services/data/v66.0/jobs/query/750TEST002', '{"id":"750TEST002","state":"JobComplete"}');
        mock.addResponse(
            '/services/data/v66.0/jobs/query/750TEST002/results',
            '"Id","Name"' + '\n' + '"001000000000002AAA","Bulk SObject"'
        );
        Test.setMock(HttpCalloutMock.class, mock);

        SoqlQuery q = SoqlQuery.of('Account')
            .field('Id')
            .field('Name')
            .useDriver(new SoqlQuery.RestDriver('MyOrg').useEngine(new SoqlQuery.BulkV2QueryEngine()));

        // Act
        Test.startTest();
        List<Object> results = q.fetchInto(List<Account>.class);
        Test.stopTest();

        // Assert
        Assert.areEqual(1, results.size());
        Account acc = (Account) results[0];
        Assert.areEqual('Bulk SObject', acc.Name);
    }

    @IsTest
    static void should_execute_bulk_v2_query_into_dto_and_normalize_custom_keys() {
        // Arrange
        MockRest mock = new MockRest();
        mock.addResponse('/services/data/v66.0/jobs/query', '{"id":"750TEST003"}');
        mock.addResponse('/services/data/v66.0/jobs/query/750TEST003', '{"id":"750TEST003","state":"JobComplete"}');
        mock.addResponse(
            '/services/data/v66.0/jobs/query/750TEST003/results',
            '"Id","Name","ExternalId__c","IsDeleted","Owner.Name","Owner.Profile.Name"' +
                '\n' +
                '"001000000000003AAA","Bulk DTO","EXT-1","false","User User","System Administrator"'
        );
        Test.setMock(HttpCalloutMock.class, mock);

        SoqlQuery q = SoqlQuery.of('Account')
            .field('Id')
            .field('Name')
            .field('ExternalId__c')
            .field('IsDeleted')
            .field('Owner.Name')
            .field('Owner.Profile.Name')
            .useDriver(new SoqlQuery.RestDriver('MyOrg').useEngine(new SoqlQuery.BulkV2QueryEngine()));

        // Act
        Test.startTest();
        List<Object> results = q.fetchInto(List<QueryAccountDto>.class);
        Test.stopTest();

        // Assert
        Assert.areEqual(1, results.size());
        QueryAccountDto dto = (QueryAccountDto) results[0];
        Assert.areEqual('Bulk DTO', dto.Name);
        Assert.areEqual('EXT-1', dto.ExternalId_c);
        Assert.areEqual(false, dto.IsDeleted);
        Assert.isNotNull(dto.Owner);
        Assert.areEqual('User User', dto.Owner.Name);
        Assert.isNotNull(dto.Owner.Profile);
        Assert.areEqual('System Administrator', dto.Owner.Profile.Name);
    }

    @IsTest
    static void should_use_query_all_operation_for_bulk_v2_when_all_rows_is_requested() {
        // Arrange
        MockRest mock = new MockRest();
        mock.addResponse('/services/data/v66.0/jobs/query', '{"id":"750TEST004"}');
        mock.addResponse('/services/data/v66.0/jobs/query/750TEST004', '{"id":"750TEST004","state":"JobComplete"}');
        mock.addResponse('/services/data/v66.0/jobs/query/750TEST004/results', '"Id"' + '\n' + '"001000000000004AAA"');
        Test.setMock(HttpCalloutMock.class, mock);

        SoqlQuery q = SoqlQuery.of('Account')
            .field('Id')
            .allRows()
            .useDriver(new SoqlQuery.RestDriver('MyOrg').useEngine(new SoqlQuery.BulkV2QueryEngine()));

        // Act
        Test.startTest();
        q.fetchInto(List<Map<String, Object>>.class);
        Test.stopTest();

        // Assert
        String payload = mock.getRequestBody('/services/data/v66.0/jobs/query');
        Assert.isNotNull(payload);
        Assert.isTrue(payload.contains('"operation":"queryAll"'));
        Assert.isFalse(payload.toLowerCase().contains(' all rows'));
    }

    @IsTest
    static void should_apply_max_records_request_parameter_for_bulk_v2_results() {
        // Arrange
        MockRest mock = new MockRest();
        mock.addResponse('/services/data/v66.0/jobs/query', '{"id":"750TEST005"}');
        mock.addResponse('/services/data/v66.0/jobs/query/750TEST005', '{"id":"750TEST005","state":"JobComplete"}');
        mock.addResponse('/services/data/v66.0/jobs/query/750TEST005/results?maxRecords=1', '"Id"' + '\n' + '"001"');
        Test.setMock(HttpCalloutMock.class, mock);

        SoqlQuery q = SoqlQuery.of('Account')
            .field('Id')
            .useDriver(new SoqlQuery.RestDriver('MyOrg').useEngine(new SoqlQuery.BulkV2QueryEngine().setMaxRecords(1)));

        // Act
        Test.startTest();
        q.fetchInto(List<Map<String, Object>>.class);
        Test.stopTest();

        // Assert
        Assert.isTrue(
            mock.hasRequestedPath('/services/data/v66.0/jobs/query/750TEST005/results?maxRecords=1'),
            'Expected Bulk results request to include maxRecords query parameter'
        );
    }

    @IsTest
    static void should_not_follow_bulk_locator_when_query_more_disabled() {
        // Arrange
        MockRest mock = new MockRest();
        mock.addResponse('/services/data/v66.0/jobs/query', '{"id":"750TEST006"}');
        mock.addResponse('/services/data/v66.0/jobs/query/750TEST006', '{"id":"750TEST006","state":"JobComplete"}');
        mock.addResponse(
            '/services/data/v66.0/jobs/query/750TEST006/results?maxRecords=1',
            '"Id","Name"' + '\n' + '"001A","A"',
            new Map<String, String>{ 'Sforce-Locator' => 'loc-1' }
        );
        mock.addResponse(
            '/services/data/v66.0/jobs/query/750TEST006/results?maxRecords=1&locator=loc-1',
            '"Id","Name"' + '\n' + '"001B","B"',
            new Map<String, String>{ 'Sforce-Locator' => 'null' }
        );
        Test.setMock(HttpCalloutMock.class, mock);

        SoqlQuery q = SoqlQuery.of('Account')
            .field('Id')
            .field('Name')
            .useDriver(new SoqlQuery.RestDriver('MyOrg').useEngine(new SoqlQuery.BulkV2QueryEngine().setMaxRecords(1)));

        // Act
        Test.startTest();
        List<Object> rows = q.fetchInto(List<Map<String, Object>>.class);
        Test.stopTest();

        // Assert
        Assert.areEqual(1, rows.size());
        Assert.isFalse(
            mock.hasRequestedPath('/services/data/v66.0/jobs/query/750TEST006/results?maxRecords=1&locator=loc-1'),
            'Should not fetch additional locator page when queryMore is disabled'
        );
    }

    @IsTest
    static void should_follow_bulk_locator_when_query_more_enabled() {
        // Arrange
        MockRest mock = new MockRest();
        mock.addResponse('/services/data/v66.0/jobs/query', '{"id":"750TEST007"}');
        mock.addResponse('/services/data/v66.0/jobs/query/750TEST007', '{"id":"750TEST007","state":"JobComplete"}');
        mock.addResponse(
            '/services/data/v66.0/jobs/query/750TEST007/results?maxRecords=1',
            '"Id","Name"' + '\n' + '"001A","A"',
            new Map<String, String>{ 'Sforce-Locator' => 'loc-1' }
        );
        mock.addResponse(
            '/services/data/v66.0/jobs/query/750TEST007/results?maxRecords=1&locator=loc-1',
            '"Id","Name"' + '\n' + '"001B","B"',
            new Map<String, String>{ 'Sforce-Locator' => 'null' }
        );
        Test.setMock(HttpCalloutMock.class, mock);

        SoqlQuery q = SoqlQuery.of('Account')
            .field('Id')
            .field('Name')
            .useDriver(
                new SoqlQuery.RestDriver('MyOrg')
                    .useEngine(new SoqlQuery.BulkV2QueryEngine().setMaxRecords(1).setQueryMore(true))
            );

        // Act
        Test.startTest();
        List<Object> rows = q.fetchInto(List<Map<String, Object>>.class);
        Test.stopTest();

        // Assert
        Assert.areEqual(2, rows.size());
        Assert.isTrue(
            mock.hasRequestedPath('/services/data/v66.0/jobs/query/750TEST007/results?maxRecords=1&locator=loc-1'),
            'Should fetch additional locator page when queryMore is enabled'
        );
    }

    @IsTest
    static void should_fetch_bulk_locator_lazily() {
        // Arrange
        MockRest mock = new MockRest();
        mock.addResponse('/services/data/v66.0/jobs/query', '{"id":"750TEST008"}');
        mock.addResponse('/services/data/v66.0/jobs/query/750TEST008', '{"id":"750TEST008","state":"JobComplete"}');
        mock.addResponse(
            '/services/data/v66.0/jobs/query/750TEST008/results?maxRecords=1',
            '"Id","Name"' + '\n' + '"001A","A"',
            new Map<String, String>{ 'Sforce-Locator' => 'loc-1' }
        );
        mock.addResponse(
            '/services/data/v66.0/jobs/query/750TEST008/results?maxRecords=1&locator=loc-1',
            '"Id","Name"' + '\n' + '"001B","B"',
            new Map<String, String>{ 'Sforce-Locator' => 'null' }
        );
        Test.setMock(HttpCalloutMock.class, mock);

        SoqlQuery q = SoqlQuery.of('Account')
            .field('Id')
            .field('Name')
            .useDriver(
                new SoqlQuery.RestDriver('MyOrg')
                    .useEngine(new SoqlQuery.BulkV2QueryEngine().setMaxRecords(1).setQueryMore(true))
            );

        // Act
        Test.startTest();
        Iterator<Object> it = q.fetchLazyInto(List<Map<String, Object>>.class).iterator();
        Assert.isTrue(it.hasNext(), 'First page should be fetched on first hasNext');
        Assert.isFalse(
            mock.hasRequestedPath('/services/data/v66.0/jobs/query/750TEST008/results?maxRecords=1&locator=loc-1'),
            'Second page should not be fetched before first page is consumed'
        );
        it.next();
        Assert.isTrue(it.hasNext(), 'Second page should be fetched once first page is exhausted');
        Test.stopTest();

        // Assert
        Assert.isTrue(
            mock.hasRequestedPath('/services/data/v66.0/jobs/query/750TEST008/results?maxRecords=1&locator=loc-1'),
            'Second page should be fetched lazily'
        );
    }

    // </editor-fold>

    // <editor-fold desc="SObjectCollectionsEngine">
    @IsTest
    static void should_execute_sobject_collections_query_with_id_in_bind() {
        // Arrange
        Id id1 = fakeId(Account.SObjectType);
        Id id2 = fakeId(Account.SObjectType);
        MockCollectionsDriver driver = new MockCollectionsDriver();
        driver.useEngine(new SoqlQuery.SObjectCollectionsEngine());
        List<String> ids = new List<String>{ id1, id2 };

        SoqlQuery q = SoqlQuery.of('Account').fields('Id, Name').addConditionIn('Id', ids).useDriver(driver).debug();

        // Act
        Test.startTest();
        List<Object> rows = q.fetchInto(List<Account>.class);
        Test.stopTest();

        // Assert
        Assert.areEqual(1, driver.requestedIdChunks.size());
        Assert.areEqual(2, driver.requestedIdChunks[0].size());
        Assert.areEqual(id1, driver.requestedIdChunks[0][0]);
        Assert.isTrue(
            driver.endpoints[0].contains('/services/data/v66.0/composite/sobjects/Account'),
            'Engine should call sObject Collections endpoint with encoded fields'
        );
        Assert.areEqual(2, rows.size());
        Assert.areEqual('Name-' + id1, ((Account) rows[0]).Name);
        Assert.areEqual(true, driver.requestBodyHasFields[0], 'Body should include fields for explicit select list');
    }

    @IsTest
    static void should_chunk_sobject_collections_requests_when_ids_exceed_chunk_size() {
        // Arrange
        Id id1 = fakeId(Account.SObjectType);
        Id id2 = fakeId(Account.SObjectType);
        Id id3 = fakeId(Account.SObjectType);
        Id id4 = fakeId(Account.SObjectType);
        Id id5 = fakeId(Account.SObjectType);
        MockCollectionsDriver driver = new MockCollectionsDriver();
        driver.useEngine(new SoqlQuery.SObjectCollectionsEngine().setChunkSize(2));
        List<String> ids = new List<String>{ id1, id2, id3, id4, id5 };
        SoqlQuery q = SoqlQuery.of('Account').fields('Id, Name').addConditionIn('Id', ids).useDriver(driver);

        // Act
        Test.startTest();
        List<Object> rows = q.fetchInto(List<Map<String, Object>>.class);
        Test.stopTest();

        // Assert
        Assert.areEqual(3, driver.requestedIdChunks.size(), 'Expected chunking into 2/2/1 requests');
        Assert.areEqual(2, driver.requestedIdChunks[0].size());
        Assert.areEqual(2, driver.requestedIdChunks[1].size());
        Assert.areEqual(1, driver.requestedIdChunks[2].size());
        Assert.areEqual(5, rows.size(), 'All requested IDs should be returned');
    }

    @IsTest
    static void should_fetch_sobject_collections_chunks_lazily() {
        // Arrange
        Id id1 = fakeId(Account.SObjectType);
        Id id2 = fakeId(Account.SObjectType);
        MockCollectionsDriver driver = new MockCollectionsDriver();
        driver.useEngine(new SoqlQuery.SObjectCollectionsEngine().setChunkSize(1));
        SoqlQuery q = SoqlQuery.of('Account')
            .fields('Id, Name')
            .addConditionIn('Id', new List<String>{ id1, id2 })
            .useDriver(driver);

        // Act
        Test.startTest();
        Iterator<Object> it = q.fetchLazyInto(List<Account>.class).iterator();
        Assert.areEqual(0, driver.requestedIdChunks.size(), 'No chunks should be fetched before iteration');
        Assert.isTrue(it.hasNext(), 'First chunk should be fetched on first hasNext');
        Assert.areEqual(1, driver.requestedIdChunks.size(), 'First chunk should be fetched lazily');
        it.next();
        Assert.areEqual(1, driver.requestedIdChunks.size(), 'Second chunk should not be fetched yet');
        Assert.isTrue(it.hasNext(), 'Second chunk should be fetched when needed');
        Assert.areEqual(2, driver.requestedIdChunks.size(), 'Second chunk should be fetched lazily');
        Test.stopTest();
    }

    @IsTest
    static void should_handle_null_element_responses_for_sobject_collections() {
        // Arrange
        Id id1 = fakeId(Account.SObjectType);
        Id id2 = fakeId(Account.SObjectType);
        MockCollectionsDriverWithNull driver = new MockCollectionsDriverWithNull(id2);
        driver.useEngine(new SoqlQuery.SObjectCollectionsEngine());
        SoqlQuery q = SoqlQuery.of('Account')
            .fields('Id, Name')
            .addConditionIn('Id', new List<String>{ id1, id2 })
            .useDriver(driver);

        // Act
        Test.startTest();
        List<Object> rows = q.fetchInto(List<Account>.class);
        Test.stopTest();

        // Assert
        Assert.areEqual(2, rows.size(), 'Null element should be preserved in result size');
        Assert.areEqual(null, rows[0], 'Missing record should deserialize as null element');
        Assert.areEqual('Name-' + id2, ((Account) rows[1]).Name);
    }

    @IsTest
    static void should_reject_unsupported_where_shape_for_sobject_collections_engine() {
        // Arrange
        MockCollectionsDriver driver = new MockCollectionsDriver();
        driver.useEngine(new SoqlQuery.SObjectCollectionsEngine());
        SoqlQuery q = SoqlQuery.of('Account').fields('Id, Name').addConditionEq('Name', 'Acme').useDriver(driver);

        // Act / Assert
        try {
            q.fetchInto(List<Map<String, Object>>.class);
            Assert.fail('Expected QueryException for unsupported WHERE shape');
        } catch (Query.QueryException e) {
            Assert.isTrue(e.getMessage().contains('supports only WHERE Id = ... or Id IN ...'));
        }
        Assert.areEqual(0, driver.requestedIdChunks.size(), 'No callouts should be executed on invalid shape');
    }

    // </editor-fold>

    // <editor-fold desc="QueryMoreIterator">
    @IsTest
    static void should_execute_paged_rest_query() {
        // Arrange
        MockRest mock = new MockRest();
        mock.addResponse(
            '/services/data/v66.0/query/?q=SELECT+Name+FROM+Account',
            '{"totalSize":2, "done":false, "nextRecordsUrl":"/services/data/v66.0/query/batch2", "records":[{"attributes":{"type":"Account"}, "Name":"Batch1"}]}'
        );
        mock.addResponse(
            '/services/data/v66.0/query/batch2',
            '{"totalSize":2, "done":true, "records":[{"attributes":{"type":"Account"}, "Name":"Batch2"}]}'
        );
        Test.setMock(HttpCalloutMock.class, mock);

        SoqlQuery q = SoqlQuery.of('Account')
            .field('Name')
            .useDriver(new SoqlQuery.RestDriver('MyOrg').useEngine(new SoqlQuery.QueryEngine().setQueryMore(true)));

        // Act
        Test.startTest();
        Iterable<SObject> iterable = q.fetchLazy();
        List<SObject> results = new List<SObject>();
        for (SObject record : iterable) {
            results.add(record);
        }
        Test.stopTest();

        // Assert
        Assert.areEqual(2, results.size());
        Assert.areEqual('Batch1', results[0].get('Name'));
        Assert.areEqual('Batch2', results[1].get('Name'));
    }

    @IsTest
    static void should_handle_empty_lazy_result() {
        // Arrange
        MockRest mock = new MockRest();
        mock.addResponse(
            '/services/data/v66.0/query/?q=SELECT+Name+FROM+Account',
            '{"totalSize":0, "done":true, "records":[]}'
        );
        Test.setMock(HttpCalloutMock.class, mock);

        SoqlQuery q = SoqlQuery.of('Account').field('Name').useDriver(new SoqlQuery.RestDriver('MyOrg'));

        // Act
        Test.startTest();
        Iterator<SObject> it = q.fetchLazy().iterator();
        Boolean hasNext = it.hasNext();
        Test.stopTest();

        // Assert
        Assert.isFalse(hasNext, 'Should not have results for empty response');
    }

    @IsTest
    static void should_handle_error_on_subsequent_page_fetch() {
        // Arrange
        MockRest mock = new MockRest();
        mock.addResponse(
            '/services/data/v66.0/query/?q=SELECT+Name+FROM+Account',
            '{"totalSize":2, "done":false, "nextRecordsUrl":"/services/data/v66.0/query/fail-page", "records":[{"attributes":{"type":"Account"}, "Name":"Batch1"}]}'
        );
        mock.addError('/services/data/v66.0/query/fail-page', 500, 'Server Error');
        Test.setMock(HttpCalloutMock.class, mock);

        SoqlQuery q = SoqlQuery.of('Account')
            .field('Name')
            .useDriver(new SoqlQuery.RestDriver('MyOrg').useEngine(new SoqlQuery.QueryEngine().setQueryMore(true)));

        // Act & Assert
        Test.startTest();
        Iterator<SObject> it = q.fetchLazy().iterator();
        try {
            it.hasNext();
            it.next();
            Assert.fail('Expected QueryException on failed subsequent page fetch');
        } catch (Query.QueryException e) {
            Assert.isTrue(
                e.getMessage().contains('REST API Error') ||
                    e.getMessage().contains('Server Error') ||
                    e.getMessage().contains('REST Composite sub-request failed')
            );
        }
        Test.stopTest();
    }
    // </editor-fold>

    // <editor-fold desc="QueryEngine">
    @IsTest
    static void should_execute_count_rest_query() {
        // Arrange
        MockRest mock = new MockRest();
        mock.addResponse(
            '/services/data/v66.0/query/?q=SELECT+COUNT%28%29+FROM+Account',
            '{"totalSize":42, "done":true, "records":[]}'
        );
        Test.setMock(HttpCalloutMock.class, mock);

        SoqlQuery q = SoqlQuery.of('Account').useDriver(new SoqlQuery.RestDriver('MyOrg'));

        // Act
        Test.startTest();
        Integer count = q.fetchCount();
        Test.stopTest();

        // Assert
        Assert.areEqual(42, count);
    }

    @IsTest
    static void should_execute_count_via_tooling_when_enabled() {
        // Arrange
        MockRest mock = new MockRest();
        mock.addResponse(
            '/services/data/v66.0/tooling/query/?q=SELECT+COUNT%28%29+FROM+Account',
            '{"totalSize":7, "done":true, "records":[]}'
        );
        Test.setMock(HttpCalloutMock.class, mock);

        SoqlQuery q = SoqlQuery.of('Account')
            .useDriver(new SoqlQuery.RestDriver('MyOrg').useEngine(new SoqlQuery.QueryEngine().useTooling(true)));

        // Act
        Test.startTest();
        Integer count = q.fetchCount();
        Test.stopTest();

        // Assert
        Assert.areEqual(7, count);
    }

    // </editor-fold>

    // <editor-fold desc="SObjectCollectionsEngine">
    @IsTest
    static void should_count_non_null_rows_for_sobject_collections_engine() {
        // Arrange
        Id id1 = fakeId(Account.SObjectType);
        Id id2 = fakeId(Account.SObjectType);
        MockCollectionsDriverWithNull driver = new MockCollectionsDriverWithNull(id2);
        driver.useEngine(new SoqlQuery.SObjectCollectionsEngine());
        SoqlQuery q = SoqlQuery.of('Account')
            .fields('Id, Name')
            .addConditionIn('Id', new List<String>{ id1, id2 })
            .useDriver(driver);

        // Act
        Test.startTest();
        Integer count = q.fetchCount();
        Test.stopTest();

        // Assert
        Assert.areEqual(1, count, 'Count should include only non-null rows');
    }

    // </editor-fold>

    // <editor-fold desc="BulkV2QueryEngine">
    @IsTest
    static void should_execute_bulk_v2_count_from_number_records_processed() {
        // Arrange
        MockRest mock = new MockRest();
        mock.addResponse('/services/data/v66.0/jobs/query', '{"id":"750TESTCOUNT"}');
        mock.addResponse(
            '/services/data/v66.0/jobs/query/750TESTCOUNT',
            '{"id":"750TESTCOUNT","state":"JobComplete","numberRecordsProcessed":42}'
        );
        Test.setMock(HttpCalloutMock.class, mock);

        SoqlQuery q = SoqlQuery.of('Account')
            .useDriver(new SoqlQuery.RestDriver('MyOrg').useEngine(new SoqlQuery.BulkV2QueryEngine()));

        // Act
        Test.startTest();
        Integer count = q.fetchCount();
        Test.stopTest();

        // Assert
        Assert.areEqual(42, count);
        String createPayload = mock.getRequestBody('/services/data/v66.0/jobs/query');
        Assert.isFalse(
            createPayload.toUpperCase().contains('COUNT('),
            'Bulk count should rewrite aggregate COUNT query to non-aggregate query'
        );
        Assert.isFalse(
            mock.hasRequestedPath('/services/data/v66.0/jobs/query/750TESTCOUNT/results'),
            'Bulk count should not fetch results payload'
        );
    }
    // </editor-fold>

    // <editor-fold desc="QueryEngine">
    @IsTest
    static void should_handle_rest_error() {
        // Arrange
        MockRest mock = new MockRest();
        mock.addError('/services/data/v66.0/query/?q=SELECT+Name+FROM+Account', 400, 'Bad Request');
        Test.setMock(HttpCalloutMock.class, mock);

        SoqlQuery q = SoqlQuery.of('Account').field('Name').useDriver(new SoqlQuery.RestDriver('MyOrg'));

        // Act & Assert
        try {
            q.fetch();
            Assert.fail('Expected QueryException');
        } catch (Query.QueryException e) {
            Assert.isTrue(e.getMessage().contains('REST Query Failed'), 'Error message: ' + e.getMessage());
        }
    }
    // </editor-fold>

    // <editor-fold desc="QueryEngine">
    @IsTest
    static void should_handle_all_fields_with_properties_via_rest() {
        // Arrange
        MockRest mock = new MockRest();
        mock.addResponse(
            '/services/data/v66.0/sobjects/Account/describe',
            '{"name":"Account", "fields":[{"name":"Id", "updateable":false, "createable":false, "aggregatable":true, "calculated":false, "custom":false, "encrypted":false, "externalId":false, "filterable":true, "groupable":true, "idLookup":true, "nillable":false, "sortable":true, "unique":false}]}'
        );
        Test.setMock(HttpCalloutMock.class, mock);

        SoqlQuery q = SoqlQuery.of('Account').useDriver(new SoqlQuery.RestDriver('MyOrg'));

        // Act
        Test.startTest();
        q.allFields(
            new List<SoqlQuery.FieldProperty>{
                SoqlQuery.FieldProperty.ACCESSIBLE,
                SoqlQuery.FieldProperty.AGGREGATABLE
            }
        );
        Test.stopTest();

        // Assert
        Assert.isTrue(q.toString().contains('Id'));
    }

    @IsTest
    static void should_cover_all_field_checker_properties_for_rest() {
        // Arrange
        String fieldJson = '{"name":"Id", "updateable":true, "createable":true, "aggregatable":true, "calculated":true, "custom":true, "encrypted":true, "externalId":true, "filterable":true, "groupable":true, "idLookup":true, "nillable":true, "sortable":true, "unique":true}';
        SoqlQuery.FieldDto dto = (SoqlQuery.FieldDto) JSON.deserialize(fieldJson, SoqlQuery.FieldDto.class);

        // Act & Assert
        for (SoqlQuery.FieldProperty prop : SoqlQuery.FieldProperty.values()) {
            Assert.isTrue(new SoqlQuery.FieldChecker(dto, new List<SoqlQuery.FieldProperty>{ prop }).every());
        }
    }

    @IsTest
    static void should_throw_on_field_set_with_rest_descriptor() {
        // Arrange
        MockRest mock = new MockRest();
        mock.addResponse('/services/data/v66.0/sobjects/Account/describe', '{"name":"Account", "fields":[]}');
        Test.setMock(HttpCalloutMock.class, mock);
        SoqlQuery q = SoqlQuery.of('Account').useDriver(new SoqlQuery.RestDriver('MyOrg'));

        // Act & Assert
        try {
            q.fieldSet('MyFieldSet');
            Assert.fail('Expected QueryException');
        } catch (Query.QueryException e) {
            Assert.isTrue(
                e.getMessage().contains('Schema-based discovery (fieldSet) is not supported for remote drivers')
            );
        }
    }

    @IsTest
    static void should_cache_rest_describe_response() {
        // Arrange
        MockRest mock = new MockRest();
        mock.addResponse('/services/data/v66.0/sobjects/Account/describe', '{"name":"Account", "fields":[]}');
        Test.setMock(HttpCalloutMock.class, mock);
        SoqlQuery q = SoqlQuery.of('Account').useDriver(new SoqlQuery.RestDriver('MyOrg'));

        // Act
        Test.startTest();
        q.allDescribeFields();
        q.allDescribeFields();
        Test.stopTest();

        // Assert
        Assert.areEqual(1, mockCount(mock), 'Should have only called REST API once');
    }

    private static Integer mockCount(MockRest mock) {
        return mock.callCount;
    }
    // </editor-fold>

    // <editor-fold desc="QueryEngine">
    @IsTest
    static void should_throw_on_unsupported_operations() {
        // Arrange
        SoqlQuery.RestDriver driver = new SoqlQuery.RestDriver('MyOrg');
        SoqlQuery.QueryArgs queryArgs = new SoqlQuery.QueryArgs(
            'SELECT Name FROM Account',
            'SELECT Name FROM Account',
            new Map<String, Object>(),
            AccessLevel.USER_MODE
        );

        // Act & Assert
        try {
            driver.locator(queryArgs);
            Assert.fail('Expected QueryException for locator');
        } catch (Query.QueryException e) {
            Assert.areEqual('REST API does not support QueryLocator', e.getMessage());
        }

        try {
            driver.cursor(queryArgs);
            Assert.fail('Expected QueryException for cursor');
        } catch (Query.QueryException e) {
            Assert.areEqual('REST API does not support Cursor', e.getMessage());
        }

        try {
            driver.paginationCursor(queryArgs);
            Assert.fail('Expected QueryException for paginationCursor');
        } catch (Query.QueryException e) {
            Assert.areEqual('REST API does not support PaginationCursor', e.getMessage());
        }
    }

    @IsTest
    static void should_execute_explain_via_rest() {
        // Arrange
        MockRest mock = new MockRest();
        mock.addResponse(
            '/services/data/v66.0/query/?explain=SELECT+Name+FROM+Account',
            '{"queryPlan":[{"cardinality":1, "sobjectType":"Account", "relativeCost":1.0, "sobjectCardinality":1, "notes":[], "fields":[]}]}'
        );
        Test.setMock(HttpCalloutMock.class, mock);
        SoqlQuery q = SoqlQuery.of('Account').field('Name').useDriver(new SoqlQuery.RestDriver('MyOrg'));

        // Act
        Test.startTest();
        Object plan = q.explain();
        Test.stopTest();

        // Assert
        Assert.isNotNull(plan);
        Map<String, Object> planMap = (Map<String, Object>) plan;
        Assert.isTrue(planMap.containsKey('queryPlan'));
    }

    @IsTest
    static void should_throw_on_system_mode() {
        // Arrange
        SoqlQuery.RestDriver driver = new SoqlQuery.RestDriver('MyOrg');
        SoqlQuery.QueryArgs queryArgs = new SoqlQuery.QueryArgs(
            'SELECT count() FROM Account',
            'SELECT count() FROM Account',
            null,
            AccessLevel.SYSTEM_MODE
        );
        queryArgs.listType = List<SObject>.class;

        // Act & Assert
        try {
            driver.runMore(queryArgs);
            Assert.fail('RestDriver should not allow SYSTEM_MODE');
        } catch (Query.QueryException e) {
            Assert.isTrue(e.getMessage().contains('RestDriver requires AccessLevel.USER_MODE'));
        }
    }

    @IsTest
    static void should_fetch_all_subquery_results() {
        // Arrange
        Id id1 = fakeId(Task.SObjectType);
        Id id2 = fakeId(Task.SObjectType);
        Id id3 = fakeId(Task.SObjectType);
        Id id4 = fakeId(Task.SObjectType);
        Id id5 = fakeId(Task.SObjectType);
        Id id6 = fakeId(Account.SObjectType);
        MockRest mock = new MockRest();
        Map<String, Object> subQueryPage1 = new Map<String, Object>{
            'totalSize' => 5,
            'done' => false,
            'nextRecordsUrl' => '/services/data/v66.0/query/0r8xx58oJdvoG0qAIE-200',
            'records' => new List<Object>{
                new Map<String, Object>{
                    'attributes' => new Map<String, Object>{ 'type' => 'Task' },
                    'Id' => id1,
                    'Subject' => 'Task 1'
                },
                new Map<String, Object>{
                    'attributes' => new Map<String, Object>{ 'type' => 'Task' },
                    'Id' => id2,
                    'Subject' => 'Task 2'
                }
            }
        };

        Map<String, Object> subQueryPage2 = new Map<String, Object>{
            'totalSize' => 5,
            'done' => true,
            'records' => new List<Object>{
                new Map<String, Object>{
                    'attributes' => new Map<String, Object>{ 'type' => 'Task' },
                    'Id' => id3,
                    'Subject' => 'Task 3'
                },
                new Map<String, Object>{
                    'attributes' => new Map<String, Object>{ 'type' => 'Task' },
                    'Id' => id4,
                    'Subject' => 'Task 4'
                },
                new Map<String, Object>{
                    'attributes' => new Map<String, Object>{ 'type' => 'Task' },
                    'Id' => id5,
                    'Subject' => 'Task 5'
                }
            }
        };

        Map<String, Object> accountRecord = new Map<String, Object>{
            'attributes' => new Map<String, Object>{ 'type' => 'Account' },
            'Id' => id6,
            'Name' => 'Account 1',
            'Tasks' => subQueryPage1
        };

        Map<String, Object> mainResponse = new Map<String, Object>{
            'totalSize' => 1,
            'done' => true,
            'records' => new List<Object>{ accountRecord }
        };

        mock.addResponse(
            '/services/data/v66.0/query/?q=' +
            EncodingUtil.urlEncode('SELECT Name, (SELECT Subject FROM Tasks) FROM Account', 'UTF-8'),
            JSON.serialize(mainResponse)
        );
        mock.addResponse('/services/data/v66.0/query/0r8xx58oJdvoG0qAIE-200', JSON.serialize(subQueryPage2));

        Test.setMock(HttpCalloutMock.class, mock);

        SoqlQuery q = SoqlQuery.of('Account')
            .field('Name')
            .subQuery('Tasks', SoqlQuery.of('Task').field('Subject'))
            .useDriver(new SoqlQuery.RestDriver('MyOrg').useEngine(new SoqlQuery.QueryEngine().setQueryMore(true)));

        // Act
        List<Account> results = q.fetch();

        // Assert
        System.assertEquals(1, results.size());
        List<Task> tasks = results[0].Tasks;
        System.assertNotEquals(null, tasks);
        System.assertEquals(5, tasks.size());
    }

    @IsTest
    static void should_fetch_deeply_nested_subqueries() {
        // Arrange
        Id id1 = fakeId(Case.SObjectType);
        Id id2 = fakeId(Case.SObjectType);
        Id id3 = fakeId(Contact.SObjectType);
        Id id4 = fakeId(Account.SObjectType);
        MockRest mock = new MockRest();
        Map<String, Object> grandChildPage = new Map<String, Object>{
            'totalSize' => 5,
            'done' => false,
            'nextRecordsUrl' => '/grandchild/next',
            'records' => new List<Object>{
                new Map<String, Object>{
                    'attributes' => new Map<String, Object>{ 'type' => 'Case' },
                    'Id' => id1,
                    'Subject' => 'GrandChild 1'
                }
            }
        };
        Map<String, Object> grandChildPage2 = new Map<String, Object>{
            'totalSize' => 5,
            'done' => true,
            'records' => new List<Object>{
                new Map<String, Object>{
                    'attributes' => new Map<String, Object>{ 'type' => 'Case' },
                    'Id' => id2,
                    'Subject' => 'GrandChild 2'
                }
            }
        };

        Map<String, Object> childRecord = new Map<String, Object>{
            'attributes' => new Map<String, Object>{ 'type' => 'Contact' },
            'Id' => id3,
            'LastName' => 'Child',
            'Cases' => grandChildPage
        };

        Map<String, Object> parentPage = new Map<String, Object>{
            'totalSize' => 1,
            'done' => true,
            'records' => new List<Object>{
                new Map<String, Object>{
                    'attributes' => new Map<String, Object>{ 'type' => 'Account' },
                    'Id' => id4,
                    'Name' => 'Parent',
                    'Contacts' => new Map<String, Object>{
                        'totalSize' => 1,
                        'done' => true,
                        'records' => new List<Object>{ childRecord }
                    }
                }
            }
        };

        String query = 'SELECT Id, (SELECT Id, (SELECT Id FROM Cases) FROM Contacts) FROM Account';
        mock.addResponse(
            '/services/data/v66.0/query/?q=' + EncodingUtil.urlEncode(query, 'UTF-8'),
            JSON.serialize(parentPage)
        );
        mock.addResponse('/grandchild/next', JSON.serialize(grandChildPage2));
        SoqlQuery.QueryArgs queryArgs = new SoqlQuery.QueryArgs(query, query, null, null);
        queryArgs.listType = List<Map<String, Object>>.class;
        queryArgs.subQueryHierarchy = new Map<String, Set<String>>{
            '' => new Set<String>{ 'Contacts' },
            'Contacts' => new Set<String>{ 'Cases' }
        };

        SoqlQuery.RestDriver driver = new SoqlQuery.RestDriver('MyOrg')
            .useEngine(new SoqlQuery.QueryEngine().setQueryMore(true));
        Test.setMock(HttpCalloutMock.class, mock);

        // Act
        List<Object> accounts = driver.run(queryArgs);

        // Assert
        System.assertEquals(1, accounts.size());
        System.assertEquals(2, mock.callCount);
    }

    @IsTest
    static void should_not_fetch_additional_pages_when_query_more_disabled() {
        // Arrange
        MockRest mock = new MockRest();
        mock.addResponse(
            '/services/data/v66.0/query/?q=SELECT+Name+FROM+Account',
            '{"totalSize":2, "done":false, "nextRecordsUrl":"/services/data/v66.0/query/next-page", "records":[{"attributes":{"type":"Account"}, "Name":"Batch1"}]}'
        );
        mock.addResponse(
            '/services/data/v66.0/query/next-page',
            '{"totalSize":2, "done":true, "records":[{"attributes":{"type":"Account"}, "Name":"Batch2"}]}'
        );
        Test.setMock(HttpCalloutMock.class, mock);

        SoqlQuery q = SoqlQuery.of('Account')
            .field('Name')
            .useDriver(new SoqlQuery.RestDriver('MyOrg').useEngine(new SoqlQuery.QueryEngine().setQueryMore(false)));

        // Act
        Test.startTest();
        List<SObject> results = q.fetch();
        Test.stopTest();

        // Assert
        Assert.areEqual(1, results.size(), 'Should only have fetched the first page');
        Assert.areEqual('Batch1', results[0].get('Name'));
        Assert.areEqual(1, mockCount(mock), 'Should have only made one call');
    }

    @IsTest
    static void should_not_fetch_additional_subquery_pages_when_query_more_disabled() {
        // Arrange
        MockRest mock = new MockRest();
        Map<String, Object> subPage1 = new Map<String, Object>{
            'totalSize' => 5,
            'done' => false,
            'nextRecordsUrl' => '/sub/next',
            'records' => new List<Object>{
                new Map<String, Object>{
                    'attributes' => new Map<String, Object>{ 'type' => 'Task' },
                    'Id' => '00T1',
                    'Subject' => 'S1'
                }
            }
        };
        Map<String, Object> mainResponse = new Map<String, Object>{
            'totalSize' => 1,
            'done' => true,
            'records' => new List<Object>{
                new Map<String, Object>{
                    'attributes' => new Map<String, Object>{ 'type' => 'Account' },
                    'Id' => '0011',
                    'Tasks' => subPage1
                }
            }
        };

        mock.addResponse(
            '/services/data/v66.0/query/?q=' +
            EncodingUtil.urlEncode('SELECT Id, (SELECT Subject FROM Tasks) FROM Account', 'UTF-8'),
            JSON.serialize(mainResponse)
        );
        mock.addResponse(
            '/sub/next',
            '{"totalSize":5, "done":true, "records":[{"attributes":{"type":"Task"}, "Id":"00T2", "Subject":"S2"}]}'
        );
        Test.setMock(HttpCalloutMock.class, mock);

        SoqlQuery q = SoqlQuery.of('Account')
            .field('Id')
            .subQuery('Tasks', SoqlQuery.of('Task').field('Subject'))
            .useDriver(new SoqlQuery.RestDriver('MyOrg').useEngine(new SoqlQuery.QueryEngine().setQueryMore(false)));

        // Act
        List<Account> results = q.fetch();

        // Assert
        Assert.areEqual(1, results[0].Tasks.size(), 'SubQuery should have stopped after first page');
        Assert.areEqual(1, mockCount(mock));
    }

    @IsTest
    static void should_respect_batch_size_setter() {
        // Arrange
        MockRest mock = new MockRest();
        mock.addResponse(
            '/services/data/v66.0/query/?q=SELECT+Id+FROM+Account',
            '{"totalSize":0, "done":true, "records":[]}'
        );
        Test.setMock(HttpCalloutMock.class, mock);

        SoqlQuery q = SoqlQuery.of('Account')
            .useDriver(new SoqlQuery.RestDriver('MyOrg').useEngine(new SoqlQuery.QueryEngine().setBatchSize(50)));

        // Act
        q.fetch();

        // Assert
        Assert.areEqual('batchSize=50', mock.headers.get('Sforce-Query-Options'));
    }

    @IsTest
    static void should_batch_subquery_fetch_using_composite_api() {
        // Arrange
        MockRest mock = new MockRest();
        Map<String, Object> subPage1 = new Map<String, Object>{
            'totalSize' => 5,
            'done' => false,
            'nextRecordsUrl' => '/sub1/next',
            'records' => new List<Object>{
                new Map<String, Object>{ 'attributes' => new Map<String, Object>{ 'type' => 'Task' }, 'Id' => '00T1' }
            }
        };
        Map<String, Object> subPage2 = new Map<String, Object>{
            'totalSize' => 5,
            'done' => false,
            'nextRecordsUrl' => '/sub2/next',
            'records' => new List<Object>{
                new Map<String, Object>{ 'attributes' => new Map<String, Object>{ 'type' => 'Task' }, 'Id' => '00T2' }
            }
        };
        Map<String, Object> mainResponse = new Map<String, Object>{
            'totalSize' => 2,
            'done' => true,
            'records' => new List<Object>{
                new Map<String, Object>{
                    'attributes' => new Map<String, Object>{ 'type' => 'Account' },
                    'Id' => 'A1',
                    'Tasks' => subPage1
                },
                new Map<String, Object>{
                    'attributes' => new Map<String, Object>{ 'type' => 'Account' },
                    'Id' => 'A2',
                    'Tasks' => subPage2
                }
            }
        };

        mock.addResponse(
            '/services/data/v66.0/query/?q=' +
            EncodingUtil.urlEncode('SELECT Id, (SELECT Id FROM Tasks) FROM Account', 'UTF-8'),
            JSON.serialize(mainResponse)
        );
        mock.addResponse('/sub1/next', '{"totalSize":5, "done":true, "records":[{"Id":"00T1.2"}]}');
        mock.addResponse('/sub2/next', '{"totalSize":5, "done":true, "records":[{"Id":"00T2.2"}]}');
        Test.setMock(HttpCalloutMock.class, mock);

        SoqlQuery q = SoqlQuery.of('Account')
            .field('Id')
            .subQuery('Tasks', SoqlQuery.of('Task').field('Id'))
            .useDriver(new SoqlQuery.RestDriver('MyOrg').useEngine(new SoqlQuery.QueryEngine().setQueryMore(true)));

        // Act
        List<Account> results = q.fetch();

        // Assert
        Assert.areEqual(2, results.size());
        // Call 1: Root Query
        // Call 2: Composite for /sub1/next and /sub2/next
        Assert.areEqual(2, mock.callCount, 'Should have used composite to fetch both subqueries in one call');
    }

    @IsTest
    static void should_fetch_query_more_urls_sequentially_with_query_engine_and_ignore_chunk_size() {
        // Arrange
        MockRest mock = new MockRest();
        Map<String, Object> subPage1 = new Map<String, Object>{
            'totalSize' => 2,
            'done' => false,
            'nextRecordsUrl' => '/sub1/next',
            'records' => new List<Object>{
                new Map<String, Object>{ 'attributes' => new Map<String, Object>{ 'type' => 'Task' }, 'Id' => '00T1' }
            }
        };
        Map<String, Object> subPage2 = new Map<String, Object>{
            'totalSize' => 2,
            'done' => false,
            'nextRecordsUrl' => '/sub2/next',
            'records' => new List<Object>{
                new Map<String, Object>{ 'attributes' => new Map<String, Object>{ 'type' => 'Task' }, 'Id' => '00T2' }
            }
        };
        Map<String, Object> subPage3 = new Map<String, Object>{
            'totalSize' => 2,
            'done' => false,
            'nextRecordsUrl' => '/sub3/next',
            'records' => new List<Object>{
                new Map<String, Object>{ 'attributes' => new Map<String, Object>{ 'type' => 'Task' }, 'Id' => '00T3' }
            }
        };
        Map<String, Object> mainResponse = new Map<String, Object>{
            'totalSize' => 3,
            'done' => true,
            'records' => new List<Object>{
                new Map<String, Object>{
                    'attributes' => new Map<String, Object>{ 'type' => 'Account' },
                    'Id' => 'A1',
                    'Tasks' => subPage1
                },
                new Map<String, Object>{
                    'attributes' => new Map<String, Object>{ 'type' => 'Account' },
                    'Id' => 'A2',
                    'Tasks' => subPage2
                },
                new Map<String, Object>{
                    'attributes' => new Map<String, Object>{ 'type' => 'Account' },
                    'Id' => 'A3',
                    'Tasks' => subPage3
                }
            }
        };

        mock.addResponse(
            '/services/data/v66.0/query/?q=' +
            EncodingUtil.urlEncode('SELECT Id, (SELECT Id FROM Tasks) FROM Account', 'UTF-8'),
            JSON.serialize(mainResponse)
        );
        mock.addResponse('/sub1/next', '{"totalSize":2, "done":true, "records":[{"Id":"00T1.2"}]}');
        mock.addResponse('/sub2/next', '{"totalSize":2, "done":true, "records":[{"Id":"00T2.2"}]}');
        mock.addResponse('/sub3/next', '{"totalSize":2, "done":true, "records":[{"Id":"00T3.2"}]}');
        Test.setMock(HttpCalloutMock.class, mock);

        SoqlQuery q = SoqlQuery.of('Account')
            .field('Id')
            .subQuery('Tasks', SoqlQuery.of('Task').field('Id'))
            .useDriver(
                new SoqlQuery.RestDriver('MyOrg')
                    .useEngine(
                        new SoqlQuery.QueryEngine()
                            .setQueryMore(true)
                            .setChunkSize(25)
                            .useQueryMoreEngine(SoqlQuery.QueryMoreEngine.QUERY)
                    )
            );

        // Act
        List<Account> results = q.fetch();

        // Assert
        Assert.areEqual(3, results.size());
        Assert.areEqual(2, results[0].Tasks.size());
        Assert.areEqual(2, results[1].Tasks.size());
        Assert.areEqual(2, results[2].Tasks.size());
        // Root query + 3 sequential follow-up query calls.
        Assert.areEqual(4, mock.callCount, 'QUERY engine should fetch continuation URLs one by one');
    }

    @IsTest
    static void should_fail_when_composite_batch_has_errors_flag_is_true() {
        // Arrange
        MockRestEnvelopeCompat mock = new MockRestEnvelopeCompat(true);
        String query = 'SELECT Id, (SELECT Id FROM Tasks) FROM Account';
        Map<String, Object> subPage1 = new Map<String, Object>{
            'totalSize' => 2,
            'done' => false,
            'nextRecordsUrl' => '/sub/next',
            'records' => new List<Object>{
                new Map<String, Object>{ 'attributes' => new Map<String, Object>{ 'type' => 'Task' }, 'Id' => '00T1' }
            }
        };
        Map<String, Object> subPage2 = new Map<String, Object>{
            'totalSize' => 2,
            'done' => true,
            'records' => new List<Object>{
                new Map<String, Object>{ 'attributes' => new Map<String, Object>{ 'type' => 'Task' }, 'Id' => '00T2' }
            }
        };
        Map<String, Object> mainResponse = new Map<String, Object>{
            'totalSize' => 1,
            'done' => true,
            'records' => new List<Object>{
                new Map<String, Object>{
                    'attributes' => new Map<String, Object>{ 'type' => 'Account' },
                    'Id' => '0011',
                    'Tasks' => subPage1
                }
            }
        };

        mock.addResponse(
            '/services/data/v66.0/query/?q=' + EncodingUtil.urlEncode(query, 'UTF-8'),
            JSON.serialize(mainResponse)
        );
        mock.addResponse('/sub/next', JSON.serialize(subPage2));
        Test.setMock(HttpCalloutMock.class, mock);

        SoqlQuery q = SoqlQuery.of('Account')
            .field('Id')
            .subQuery('Tasks', SoqlQuery.of('Task').field('Id'))
            .useDriver(
                new SoqlQuery.RestDriver('MyOrg')
                    .useEngine(
                        new SoqlQuery.QueryEngine()
                            .setQueryMore(true)
                            .useQueryMoreEngine(SoqlQuery.QueryMoreEngine.COMPOSITE_BATCH)
                    )
            );

        // Act & Assert
        try {
            q.fetch();
            Assert.fail('Expected QueryException when Composite Batch hasErrors is true');
        } catch (Query.QueryException e) {
            Assert.isTrue(e.getMessage().contains('Composite Batch response hasErrors=true'));
        }
    }

    @IsTest
    static void should_aggregate_unique_composite_error_messages() {
        // Arrange
        MockRest mock = new MockRest();
        String query = 'SELECT Id, (SELECT Id FROM Tasks) FROM Account';
        Map<String, Object> mainResponse = new Map<String, Object>{
            'totalSize' => 3,
            'done' => true,
            'records' => new List<Object>{
                new Map<String, Object>{
                    'attributes' => new Map<String, Object>{ 'type' => 'Account' },
                    'Id' => 'A1',
                    'Tasks' => new Map<String, Object>{
                        'totalSize' => 1,
                        'done' => false,
                        'nextRecordsUrl' => '/sub1/next',
                        'records' => new List<Object>()
                    }
                },
                new Map<String, Object>{
                    'attributes' => new Map<String, Object>{ 'type' => 'Account' },
                    'Id' => 'A2',
                    'Tasks' => new Map<String, Object>{
                        'totalSize' => 1,
                        'done' => false,
                        'nextRecordsUrl' => '/sub2/next',
                        'records' => new List<Object>()
                    }
                },
                new Map<String, Object>{
                    'attributes' => new Map<String, Object>{ 'type' => 'Account' },
                    'Id' => 'A3',
                    'Tasks' => new Map<String, Object>{
                        'totalSize' => 1,
                        'done' => false,
                        'nextRecordsUrl' => '/sub3/next',
                        'records' => new List<Object>()
                    }
                }
            }
        };
        mock.addResponse(
            '/services/data/v66.0/query/?q=' + EncodingUtil.urlEncode(query, 'UTF-8'),
            JSON.serialize(mainResponse)
        );
        mock.addError('/sub1/next', 400, 'bad id 0r8xx59BNIPeK0zaA2F');
        mock.addError('/sub2/next', 400, 'bad id 0r8xx59BNIPeK0zaA2F');
        mock.addError(
            '/sub3/next',
            400,
            'The transaction was rolled back since another operation in the same transaction failed.'
        );
        Test.setMock(HttpCalloutMock.class, mock);

        SoqlQuery q = SoqlQuery.of('Account')
            .field('Id')
            .subQuery('Tasks', SoqlQuery.of('Task').field('Id'))
            .useDriver(
                new SoqlQuery.RestDriver('MyOrg')
                    .useEngine(
                        new SoqlQuery.QueryEngine()
                            .setQueryMore(true)
                            .useQueryMoreEngine(SoqlQuery.QueryMoreEngine.COMPOSITE)
                    )
            );

        // Act & Assert
        try {
            q.fetch();
            Assert.fail('Expected aggregated QueryException for Composite API');
        } catch (Query.QueryException e) {
            String message = e.getMessage();
            Assert.isTrue(message.contains('REST API Error:'));
            Assert.isTrue(message.contains('bad id 0r8xx59BNIPeK0zaA2F'));
            Assert.isTrue(
                message.contains(
                    'The transaction was rolled back since another operation in the same transaction failed.'
                )
            );
            Assert.areEqual(
                1,
                message.split('bad id 0r8xx59BNIPeK0zaA2F').size() - 1,
                'Duplicate sub-response errors must be deduplicated'
            );
        }
    }

    @IsTest
    static void should_aggregate_unique_batch_error_messages_when_has_errors_true() {
        // Arrange
        MockRest mock = new MockRest();
        String query = 'SELECT Id, (SELECT Id FROM Tasks) FROM Account';
        Map<String, Object> mainResponse = new Map<String, Object>{
            'totalSize' => 2,
            'done' => true,
            'records' => new List<Object>{
                new Map<String, Object>{
                    'attributes' => new Map<String, Object>{ 'type' => 'Account' },
                    'Id' => 'B1',
                    'Tasks' => new Map<String, Object>{
                        'totalSize' => 1,
                        'done' => false,
                        'nextRecordsUrl' => '/batch-sub1/next',
                        'records' => new List<Object>()
                    }
                },
                new Map<String, Object>{
                    'attributes' => new Map<String, Object>{ 'type' => 'Account' },
                    'Id' => 'B2',
                    'Tasks' => new Map<String, Object>{
                        'totalSize' => 1,
                        'done' => false,
                        'nextRecordsUrl' => '/batch-sub2/next',
                        'records' => new List<Object>()
                    }
                }
            }
        };
        mock.addResponse(
            '/services/data/v66.0/query/?q=' + EncodingUtil.urlEncode(query, 'UTF-8'),
            JSON.serialize(mainResponse)
        );
        mock.addError('/batch-sub1/next', 400, 'bad id 0r8xx59BNIPeK0yA2aF');
        mock.addError('/batch-sub2/next', 412, 'Batch processing halted per request');
        Test.setMock(HttpCalloutMock.class, mock);

        SoqlQuery q = SoqlQuery.of('Account')
            .field('Id')
            .subQuery('Tasks', SoqlQuery.of('Task').field('Id'))
            .useDriver(
                new SoqlQuery.RestDriver('MyOrg')
                    .useEngine(
                        new SoqlQuery.QueryEngine()
                            .setQueryMore(true)
                            .useQueryMoreEngine(SoqlQuery.QueryMoreEngine.COMPOSITE_BATCH)
                    )
            );

        // Act & Assert
        try {
            q.fetch();
            Assert.fail('Expected aggregated QueryException for Composite Batch API');
        } catch (Query.QueryException e) {
            String message = e.getMessage();
            Assert.isTrue(message.contains('REST API Error:'));
            Assert.isTrue(message.contains('bad id 0r8xx59BNIPeK0yA2aF'));
            Assert.isTrue(message.contains('Batch processing halted per request'));
        }
    }

    @IsTest
    static void should_execute_rest_query_with_direct_sobject_parsing() {
        // Arrange
        MockRest mock = new MockRest();
        mock.addResponse(
            '/services/data/v66.0/query/?q=SELECT+Name+FROM+Account',
            '{"totalSize":1, "done":true, "records":[{"attributes":{"type":"Account"}, "Name":"Acme"}]}'
        );
        Test.setMock(HttpCalloutMock.class, mock);

        SoqlQuery q = SoqlQuery.of('Account').field('Name').useDriver(new SoqlQuery.RestDriver('MyOrg'));

        // Act
        Test.startTest();
        List<SObject> results = q.fetch();
        Test.stopTest();

        // Assert
        Assert.areEqual(1, results.size());
        Assert.areEqual('Acme', results[0].get('Name'));
        Assert.isInstanceOfType(results[0], Account.class);
    }

    @IsTest
    static void should_preserve_pagination_metadata_for_untyped_results() {
        // Arrange
        MockRest mock = new MockRest();
        Map<String, Object> subPage1 = new Map<String, Object>{
            'totalSize' => 5,
            'done' => false,
            'nextRecordsUrl' => '/sub1/next',
            'records' => new List<Object>{
                new Map<String, Object>{ 'attributes' => new Map<String, Object>{ 'type' => 'Task' }, 'Id' => '00T1' }
            }
        };
        Map<String, Object> subPage2 = new Map<String, Object>{
            'totalSize' => 5,
            'done' => false,
            'nextRecordsUrl' => '/sub2/next',
            'records' => new List<Object>{
                new Map<String, Object>{ 'attributes' => new Map<String, Object>{ 'type' => 'Task' }, 'Id' => '00T2' }
            }
        };
        Map<String, Object> mainResponse = new Map<String, Object>{
            'totalSize' => 2,
            'done' => true,
            'records' => new List<Object>{
                new Map<String, Object>{
                    'attributes' => new Map<String, Object>{ 'type' => 'Account' },
                    'Id' => '0011',
                    'Tasks' => subPage1
                },
                new Map<String, Object>{
                    'attributes' => new Map<String, Object>{ 'type' => 'Account' },
                    'Id' => '0012',
                    'Tasks' => subPage2
                }
            }
        };

        mock.addResponse(
            '/services/data/v66.0/query/?q=' +
            EncodingUtil.urlEncode('SELECT Id, (SELECT Id FROM Tasks) FROM Account', 'UTF-8'),
            JSON.serialize(mainResponse)
        );
        Test.setMock(HttpCalloutMock.class, mock);

        SoqlQuery q = SoqlQuery.of('Account')
            .field('Id')
            .subQuery('Tasks', SoqlQuery.of('Task').field('Id'))
            .useDriver(new SoqlQuery.RestDriver('MyOrg').useEngine(new SoqlQuery.QueryEngine().setQueryMore(false)));

        // Act
        Test.startTest();
        List<Object> results = q.fetchInto(List<Map<String, Object>>.class);
        Test.stopTest();

        // Assert
        Assert.areEqual(2, results.size());
        Map<String, Object> acc1 = (Map<String, Object>) results[0];
        Map<String, Object> tasks1 = (Map<String, Object>) acc1.get('Tasks');

        // Key assertions: Untyped/DTO results should NOT be masked, they should show TRUE state
        Assert.areEqual(false, tasks1.get('done'), 'Untyped result should show done=false');
        Assert.areEqual('/sub1/next', tasks1.get('nextRecordsUrl'), 'Untyped result should show nextRecordsUrl');
        Assert.areEqual(1, ((List<Object>) tasks1.get('records')).size());
    }

    @IsTest
    static void should_execute_rest_query_with_direct_typed_parsing() {
        // Arrange
        MockRest mock = new MockRest();
        mock.addResponse(
            '/services/data/v66.0/query/?q=SELECT+Name+FROM+Account',
            '{"totalSize":1, "done":true, "records":[{"attributes":{"type":"Account"}, "Name":"TypedAcme"}]}'
        );
        Test.setMock(HttpCalloutMock.class, mock);

        SoqlQuery q = SoqlQuery.of('Account').field('Name').useDriver(new SoqlQuery.RestDriver('MyOrg'));

        // Act
        Test.startTest();
        List<Object> results = q.fetchInto(List<Account>.class);
        Test.stopTest();

        // Assert
        Assert.areEqual(1, results.size());
        Account acc = (Account) results[0];
        Assert.areEqual('TypedAcme', acc.Name);
    }

    @IsTest
    static void should_execute_rest_query_with_direct_typed_parsing_and_subquery() {
        // Arrange
        MockRest mock = new MockRest();
        // Main query response with a record and potential sub-query metadata (though hydration will be skipped)
        mock.addResponse(
            '/services/data/v66.0/query/?q=SELECT+Name%2C+%28SELECT+LastName+FROM+Contacts%29+FROM+Account',
            '{"totalSize":1, "done":true, "records":[{"attributes":{"type":"Account"}, "Name":"TypedAcme", "Contacts":{"totalSize":0, "done":true, "records":[]}}]}'
        );
        Test.setMock(HttpCalloutMock.class, mock);

        SoqlQuery q = SoqlQuery.of('Account')
            .field('Name')
            .subQuery('Contacts', SoqlQuery.of('Contact').field('LastName'))
            .useDriver(new SoqlQuery.RestDriver('MyOrg'));

        // Act
        Test.startTest();
        // This used to crash due to Map cast in getChildren
        List<Object> results = q.fetchInto(List<Account>.class);
        Test.stopTest();

        // Assert
        Assert.areEqual(1, results.size());
        Account acc = (Account) results[0];
        Assert.areEqual('TypedAcme', acc.Name);
    }
    // </editor-fold>

    // <editor-fold desc="QueryMoreIterator">
    @IsTest
    static void should_not_query_more_and_should_cleanup_sobject_metadata() {
        Id id1 = fakeId(Account.SObjectType);
        Id id2 = fakeId(Contact.SObjectType);
        Map<String, Object> accountRecord = new Map<String, Object>{
            'attributes' => new Map<String, Object>{ 'type' => 'Account' },
            'Id' => id1,
            'Name' => 'Acme',
            'Contacts' => page(
                new List<Object>{
                    new Map<String, Object>{
                        'attributes' => new Map<String, Object>{ 'type' => 'Contact' },
                        'Id' => id2,
                        'LastName' => 'First'
                    }
                },
                false,
                '/contacts-2'
            )
        };
        MockRestDriver driver = new MockRestDriver(page(new List<Object>{ accountRecord }, false, '/accounts-2'));

        List<SObject> records = SoqlQuery.of('Account')
            .fields('Id, Name')
            .subQuery('Contacts', SoqlQuery.of('Contact').fields('Id, LastName'))
            .useDriver(driver)
            .fetch();

        Assert.areEqual(1, records.size(), 'Should return exactly one record');
        Assert.areEqual(1, records[0].getSObjects('Contacts').size(), 'Should keep existing nested records');
        String serialized = JSON.serialize(records[0]);
        Assert.isTrue(serialized.contains('"done":true'), 'SObject payload should have done=true');
        Assert.isFalse(serialized.contains('nextRecordsUrl'), 'SObject payload should not include nextRecordsUrl');
        Assert.areEqual(1, driver.queryCalls, 'Should execute only root query call');
        Assert.areEqual(0, driver.compositeCalls + driver.compositeBatchCalls, 'Should not execute post-queries');
    }

    @IsTest
    static void should_not_transform_untyped_when_query_more_is_disabled() {
        String id1 = 'a00000001AAA';
        Map<String, Object> rootRecord = new Map<String, Object>{
            'Id' => id1,
            'Name__c' => 'Root__Name',
            'Text__c' => 'Value__kept',
            'Children__r' => page(
                new List<Object>{ new Map<String, Object>{ 'Id' => id1, 'Value__c' => 'Child__1' } },
                false,
                '/children-2'
            )
        };
        MockRestDriver driver = new MockRestDriver(page(new List<Object>{ rootRecord }, false, '/root-2'));

        List<Object> rows = SoqlQuery.of('Root__c')
            .fields('Id, Name__c, Text__c')
            .subQuery('Children__r', SoqlQuery.of('Child__c').fields('Id, Value__c'))
            .useDriver(driver)
            .fetchInto(List<Map<String, Object>>.class);
        Map<String, Object> row = (Map<String, Object>) rows[0];
        Map<String, Object> children = (Map<String, Object>) row.get('Children__r');

        Assert.isTrue(row.containsKey('Name__c'), 'Untyped payload must keep original keys');
        Assert.areEqual('Value__kept', row.get('Text__c'), 'Untyped payload must keep original values');
        Assert.areEqual(false, children.get('done'), 'Untyped payload must keep done flag as-is');
        Assert.areEqual('/children-2', children.get('nextRecordsUrl'), 'Untyped payload keeps nextRecordsUrl');
        Assert.areEqual(1, driver.queryCalls, 'Should execute only root query call');
        Assert.areEqual(0, driver.compositeCalls + driver.compositeBatchCalls, 'Should not execute post-queries');
    }

    @IsTest
    static void should_normalize_dto_keys_without_mutating_values_when_query_more_is_disabled() {
        Id id1 = fakeId(Account.SObjectType);
        Map<String, Object> rootRecord = new Map<String, Object>{
            'attributes' => new Map<String, Object>{ 'type' => 'Account' },
            'Id' => id1,
            'Name' => 'Acme',
            'ExternalId__c' => 'EXT__001',
            'Interests__c' => 'Value__kept'
        };
        MockRestDriver driver = new MockRestDriver(page(new List<Object>{ rootRecord }, false, '/root-2'));

        List<Object> rows = SoqlQuery.of('Account')
            .fields('Id, Name, ExternalId__c, Interests__c')
            .useDriver(driver)
            .fetchInto(List<QueryAccountDto>.class);
        QueryAccountDto dto = (QueryAccountDto) rows[0];

        Assert.areEqual('Acme', dto.Name, 'Base field should deserialize');
        Assert.areEqual('EXT__001', dto.ExternalId_c, 'DTO key should normalize from ExternalId__c to ExternalId_c');
        Assert.areEqual('Value__kept', dto.Interests_c, 'Normalization must not alter values');
        Assert.areEqual(1, driver.queryCalls, 'Should execute only root query call');
        Assert.areEqual(0, driver.compositeCalls + driver.compositeBatchCalls, 'Should not execute post-queries');
    }

    @IsTest
    static void should_parse_dto_with_subqueries_and_normalize_custom_suffixes() {
        Map<String, Object> accountRecord = new Map<String, Object>{
            'attributes' => new Map<String, Object>{ 'type' => 'Account' },
            'Id' => '001P000001',
            'Name' => 'Deep Nesting Acme',
            'BillingAddress' => new Map<String, Object>{ 'city' => 'San Francisco', 'country' => 'USA' },
            'ExternalId__c' => 'EXT-BILL-1',
            'Owner__r' => page(
                new List<Object>{
                    new Map<String, Object>{
                        'attributes' => new Map<String, Object>{ 'type' => 'Contact' },
                        'LastName' => 'Owner'
                    }
                },
                true,
                null
            ),
            'PersonContactId__pc' => 'PCON-123',
            'Cases' => page(
                new List<Object>{
                    new Map<String, Object>{
                        'attributes' => new Map<String, Object>{ 'type' => 'Case' },
                        'CaseNumber' => '101'
                    }
                },
                true,
                null
            ),
            'Contacts' => page(
                new List<Object>{
                    new Map<String, Object>{
                        'attributes' => new Map<String, Object>{ 'type' => 'Contact' },
                        'LastName' => 'User'
                    }
                },
                true,
                null
            ),
            'Tasks' => page(
                new List<Object>{
                    new Map<String, Object>{
                        'attributes' => new Map<String, Object>{ 'type' => 'Task' },
                        'Id' => '00TP000001',
                        'Feeds' => page(
                            new List<Object>{
                                new Map<String, Object>{
                                    'attributes' => new Map<String, Object>{ 'type' => 'FeedItem' },
                                    'Id' => '0D5P000001',
                                    'Title' => 'Test Feed'
                                }
                            },
                            true,
                            null
                        )
                    }
                },
                true,
                null
            )
        };
        MockRestDriver driver = new MockRestDriver(page(new List<Object>{ accountRecord }, true, null));

        List<Object> rows = SoqlQuery.of('Account')
            .field('Id')
            .field('Name')
            .field('BillingAddress')
            .field('ExternalId__c')
            .subQuery('Cases', SoqlQuery.of('Case').field('CaseNumber').addConditionEq('Status', 'Closed'))
            .subQuery('Contacts', SoqlQuery.of('Contact').field('LastName'))
            .subQuery(
                'Tasks',
                SoqlQuery.of('Task').field('Id').subQuery('Feeds', SoqlQuery.of('FeedItem').field('Title'))
            )
            .allRows()
            .useDriver(driver)
            .fetchInto(List<QueryAccountDto>.class);
        QueryAccountDto dto = (QueryAccountDto) rows[0];

        Assert.areEqual(1, rows.size(), 'Should return one DTO row');
        Assert.areEqual('Deep Nesting Acme', dto.Name, 'Name should deserialize');
        Assert.isNotNull(dto.BillingAddress, 'BillingAddress should deserialize');
        Assert.areEqual('San Francisco', dto.BillingAddress.city, 'BillingAddress.city should deserialize');
        Assert.areEqual('EXT-BILL-1', dto.ExternalId_c, '__c key should normalize to _c');
        Assert.areEqual('Owner', dto.Owner_r.records[0].LastName, '__r key should normalize to _r');
        Assert.areEqual('PCON-123', dto.PersonContactId_pc, '__pc key should normalize to _pc');
        Assert.areEqual('101', dto.Cases.records[0].CaseNumber, 'Cases subquery should deserialize');
        Assert.areEqual('User', dto.Contacts.records[0].LastName, 'Contacts subquery should deserialize');
        Assert.areEqual('Test Feed', dto.Tasks.records[0].Feeds.records[0].Title, 'Nested Feeds should deserialize');
        Assert.areEqual(1, driver.queryCalls, 'Should execute only one root query call');
        Assert.areEqual(0, driver.compositeCalls + driver.compositeBatchCalls, 'Should not execute post-queries');
    }

    @IsTest
    static void should_query_more_all_root_and_nested_pages_for_sobjects() {
        Id id1 = fakeId(Account.SObjectType);
        Id id2 = fakeId(Contact.SObjectType);
        Id id3 = fakeId(Account.SObjectType);
        Id id4 = fakeId(Contact.SObjectType);
        Id id5 = fakeId(Account.SObjectType);
        Id id6 = fakeId(Contact.SObjectType);
        Map<String, Object> a1 = new Map<String, Object>{
            'attributes' => new Map<String, Object>{ 'type' => 'Account' },
            'Id' => id1,
            'Name' => 'A',
            'Contacts' => page(
                new List<Object>{
                    new Map<String, Object>{
                        'attributes' => new Map<String, Object>{ 'type' => 'Contact' },
                        'Id' => id2,
                        'LastName' => 'A1'
                    }
                },
                false,
                '/contacts-a2'
            )
        };
        Map<String, Object> b1 = new Map<String, Object>{
            'attributes' => new Map<String, Object>{ 'type' => 'Account' },
            'Id' => id3,
            'Name' => 'B',
            'Contacts' => page(
                new List<Object>{
                    new Map<String, Object>{
                        'attributes' => new Map<String, Object>{ 'type' => 'Contact' },
                        'Id' => id4,
                        'LastName' => 'B1'
                    }
                },
                false,
                '/contacts-b2'
            )
        };
        Map<String, Object> c1 = new Map<String, Object>{
            'attributes' => new Map<String, Object>{ 'type' => 'Account' },
            'Id' => id5,
            'Name' => 'C',
            'Contacts' => page(
                new List<Object>{
                    new Map<String, Object>{
                        'attributes' => new Map<String, Object>{ 'type' => 'Contact' },
                        'Id' => id6,
                        'LastName' => 'C1'
                    }
                },
                true,
                null
            )
        };

        MockRestDriver driver = new MockRestDriver(page(new List<Object>{ a1 }, false, '/accounts-2'));
        driver.useEngine(new SoqlQuery.QueryEngine().setQueryMore(true).setChunkSize(2));
        driver.pagesByUrl.put('/accounts-2', page(new List<Object>{ b1 }, false, '/accounts-3'));
        driver.pagesByUrl.put('/accounts-3', page(new List<Object>{ c1 }, true, null));
        driver.pagesByUrl.put(
            '/contacts-a2',
            page(
                new List<Object>{
                    new Map<String, Object>{
                        'attributes' => new Map<String, Object>{ 'type' => 'Contact' },
                        'Id' => id2,
                        'LastName' => 'A2'
                    }
                },
                true,
                null
            )
        );
        driver.pagesByUrl.put(
            '/contacts-b2',
            page(
                new List<Object>{
                    new Map<String, Object>{
                        'attributes' => new Map<String, Object>{ 'type' => 'Contact' },
                        'Id' => id4,
                        'LastName' => 'B2'
                    }
                },
                false,
                '/contacts-b3'
            )
        );
        driver.pagesByUrl.put(
            '/contacts-b3',
            page(
                new List<Object>{
                    new Map<String, Object>{
                        'attributes' => new Map<String, Object>{ 'type' => 'Contact' },
                        'Id' => id6,
                        'LastName' => 'B3'
                    }
                },
                true,
                null
            )
        );

        List<SObject> records = SoqlQuery.of('Account')
            .fields('Id, Name')
            .subQuery('Contacts', SoqlQuery.of('Contact').fields('Id, LastName'))
            .useDriver(driver)
            .fetch();

        Assert.areEqual(3, records.size(), 'Should hydrate all root pages');
        Map<String, Integer> contactsByAccount = new Map<String, Integer>();
        for (SObject account : records) {
            contactsByAccount.put((String) account.get('Name'), account.getSObjects('Contacts').size());
        }
        Assert.areEqual(2, contactsByAccount.get('A'), 'Account A should include post-queried child rows');
        Assert.areEqual(3, contactsByAccount.get('B'), 'Account B should include all child continuation pages');
        Assert.areEqual(1, contactsByAccount.get('C'), 'Account C should include direct first-page child rows');

        String serialized = JSON.serialize(records);
        Assert.isFalse(serialized.contains('nextRecordsUrl'), 'SObject payload should not expose pagination URL');
        Assert.isFalse(serialized.contains('"done":false'), 'SObject payload should be fully marked done');
        Assert.areEqual(1, driver.queryCalls, 'Should execute exactly one root query call');
        Assert.isTrue(driver.compositeBatchCalls > 0, 'Should execute batch post-queries');
        Assert.isTrue(driver.seenUrls.contains('/accounts-2'), 'Should fetch root continuation page 2');
        Assert.isTrue(driver.seenUrls.contains('/accounts-3'), 'Should fetch root continuation page 3');
        Assert.isTrue(driver.seenUrls.contains('/contacts-a2'), 'Should fetch nested continuation for A');
        Assert.isTrue(driver.seenUrls.contains('/contacts-b2'), 'Should fetch nested continuation for B page 2');
        Assert.isTrue(driver.seenUrls.contains('/contacts-b3'), 'Should fetch nested continuation for B page 3');
    }

    @IsTest
    static void should_normalize_dto_keys_and_hydrate_custom_relationships_when_query_more_enabled() {
        Id id1 = fakeId(Account.SObjectType);
        Id id2 = fakeId(Contact.SObjectType);
        Id id3 = fakeId(Account.SObjectType);
        Id id4 = fakeId(Contact.SObjectType);
        Id id5 = fakeId(Contact.SObjectType);
        Map<String, Object> root1 = new Map<String, Object>{
            'attributes' => new Map<String, Object>{ 'type' => 'Account' },
            'Id' => id1,
            'Name' => 'Root 1',
            'ExternalId__c' => 'EXT__ROOT1',
            'Contacts' => page(
                new List<Object>{
                    new Map<String, Object>{
                        'attributes' => new Map<String, Object>{ 'type' => 'Contact' },
                        'Id' => id2,
                        'LastName' => 'V1',
                        'AccountId' => id1
                    }
                },
                false,
                '/contacts-2'
            )
        };
        Map<String, Object> root2 = new Map<String, Object>{
            'attributes' => new Map<String, Object>{ 'type' => 'Account' },
            'Id' => id3,
            'Name' => 'Root 2',
            'ExternalId__c' => 'EXT__ROOT2',
            'Contacts' => page(
                new List<Object>{
                    new Map<String, Object>{
                        'attributes' => new Map<String, Object>{ 'type' => 'Contact' },
                        'Id' => id4,
                        'LastName' => 'V3',
                        'AccountId' => id3
                    }
                },
                true,
                null
            )
        };

        MockRestDriver driver = new MockRestDriver(page(new List<Object>{ root1 }, false, '/root-2'));
        driver.useEngine(new SoqlQuery.QueryEngine().setQueryMore(true).setChunkSize(2));
        driver.pagesByUrl.put('/root-2', page(new List<Object>{ root2 }, true, null));
        driver.pagesByUrl.put(
            '/contacts-2',
            page(
                new List<Object>{
                    new Map<String, Object>{
                        'attributes' => new Map<String, Object>{ 'type' => 'Contact' },
                        'Id' => id5,
                        'LastName' => 'V2__kept',
                        'AccountId' => id1
                    }
                },
                true,
                null
            )
        );

        List<Object> rows = SoqlQuery.of('Account')
            .fields('Id, Name, ExternalId__c')
            .subQuery('Contacts', SoqlQuery.of('Contact').fields('Id, LastName, AccountId'))
            .useDriver(driver)
            .fetchInto(List<QueryAccountDto>.class);
        QueryAccountDto first = (QueryAccountDto) rows[0];

        Assert.areEqual(2, rows.size(), 'Should hydrate all root pages');
        Assert.areEqual('Root 1', first.Name, 'Root should deserialize');
        Assert.areEqual('EXT__ROOT1', first.ExternalId_c, 'DTO key normalization should apply for __c fields');
        Assert.areEqual(2, first.Contacts.records.size(), 'Nested records should include queryMore page');
        Assert.areEqual('V2__kept', first.Contacts.records[1].LastName, 'Normalization must not alter values');
        Assert.areEqual(true, first.Contacts.done, 'Nested query result should be marked done after hydration');
        Assert.isTrue(driver.seenUrls.contains('/root-2'), 'Should fetch root continuation');
        Assert.isTrue(driver.seenUrls.contains('/contacts-2'), 'Should fetch nested continuation');
    }

    @IsTest
    static void should_not_transform_untyped_when_query_more_enabled() {
        String id1 = 'a000000020AAA';
        String id2 = 'a000000021AAA';
        Map<String, Object> root1 = new Map<String, Object>{
            'Id' => id1,
            'Name__c' => 'Root__One',
            'Children__r' => page(
                new List<Object>{ new Map<String, Object>{ 'Id' => id1, 'Value__c' => 'V1' } },
                false,
                '/children-2'
            )
        };

        MockRestDriver driver = new MockRestDriver(page(new List<Object>{ root1 }, true, null));
        driver.useEngine(new SoqlQuery.QueryEngine().setQueryMore(true));
        driver.pagesByUrl.put(
            '/children-2',
            page(new List<Object>{ new Map<String, Object>{ 'Id' => id2, 'Value__c' => 'V2__kept' } }, true, null)
        );

        List<Object> rows = SoqlQuery.of('Root__c')
            .fields('Id, Name__c')
            .subQuery('Children__r', SoqlQuery.of('Child__c').fields('Id, Value__c'))
            .useDriver(driver)
            .fetchInto(List<Map<String, Object>>.class);
        Map<String, Object> first = (Map<String, Object>) rows[0];
        Map<String, Object> children = (Map<String, Object>) first.get('Children__r');
        List<Object> childRows = (List<Object>) children.get('records');
        Map<String, Object> secondChild = (Map<String, Object>) childRows[1];

        Assert.isTrue(first.containsKey('Name__c'), 'Untyped payload must keep original root key names');
        Assert.isTrue(first.containsKey('Children__r'), 'Untyped payload must keep original relationship key names');
        Assert.areEqual(2, childRows.size(), 'Untyped payload should include hydrated child continuation rows');
        Assert.areEqual('V2__kept', secondChild.get('Value__c'), 'Untyped payload must keep original values');
    }
    // </editor-fold>

    // <editor-fold desc="QueryEngine">
    @IsTest
    static void should_set_api_version_when_valid_pattern_is_provided() {
        // Arrange
        MockRest mock = new MockRest();
        mock.addResponse(
            '/services/data/v65.0/query/?q=SELECT+Name+FROM+Account',
            '{"totalSize":1, "done":true, "records":[{"attributes":{"type":"Account"}, "Name":"Acme65"}]}'
        );
        Test.setMock(HttpCalloutMock.class, mock);
        SoqlQuery.RestDriver driver = new SoqlQuery.RestDriver('MyOrg').setApiVersion('v65.0');
        SoqlQuery q = SoqlQuery.of('Account').field('Name').useDriver(driver);

        // Act
        Test.startTest();
        List<SObject> rows = q.fetch();
        Test.stopTest();

        // Assert
        Assert.areEqual(1, rows.size());
        Assert.areEqual('Acme65', rows[0].get('Name'));
    }

    @IsTest
    static void should_throw_when_describe_request_returns_non_200() {
        // Arrange
        MockRest mock = new MockRest();
        mock.addError('/services/data/v66.0/sobjects/Account/describe', 500, 'Describe failed');
        Test.setMock(HttpCalloutMock.class, mock);
        SoqlQuery.RestDriver driver = new SoqlQuery.RestDriver('MyOrg');

        // Act & Assert
        try {
            driver.getDescribeProvider().describeSObject('Account');
            Assert.fail('Expected describe to fail');
        } catch (Query.QueryException e) {
            Assert.isTrue(e.getMessage().contains('REST Describe Failed'));
        }
    }

    @IsTest
    static void should_return_first_projected_row_when_fetch_first_as_is_used() {
        // Arrange
        MockRest mock = new MockRest();
        mock.addResponse(
            '/services/data/v66.0/query/?q=SELECT+Name+FROM+Account',
            '{"totalSize":1, "done":true, "records":[{"attributes":{"type":"Account"}, "Name":"FetchFirstAs"}]}'
        );
        Test.setMock(HttpCalloutMock.class, mock);
        SoqlQuery q = SoqlQuery.of('Account').field('Name').useDriver(new SoqlQuery.RestDriver('MyOrg'));

        // Act
        Test.startTest();
        Account row = (Account) q.fetchFirstAs(Account.class);
        Test.stopTest();

        // Assert
        Assert.isNotNull(row);
        Assert.areEqual('FetchFirstAs', row.Name);
    }

    @IsTest
    static void should_enable_timer_when_use_timer_is_called() {
        // Arrange
        MockRest mock = new MockRest();
        mock.addResponse(
            '/services/data/v66.0/query/?q=SELECT+Name+FROM+Account',
            '{"totalSize":1, "done":true, "records":[{"attributes":{"type":"Account"}, "Name":"Timed"}]}'
        );
        Test.setMock(HttpCalloutMock.class, mock);
        SoqlQuery q = SoqlQuery.of('Account')
            .field('Name')
            .useTimer()
            .useTimer(Query.Timer.SYS)
            .useDriver(new SoqlQuery.RestDriver('MyOrg'));

        // Act
        Test.startTest();
        List<SObject> rows = q.fetch();
        Test.stopTest();

        // Assert
        Assert.areEqual(1, rows.size());
        Assert.areEqual('Timed', rows[0].get('Name'));
    }

    @IsTest
    static void should_project_non_instantiable_dto_when_element_has_no_default_constructor() {
        // Arrange
        MockRest mock = new MockRest();
        mock.addResponse(
            '/services/data/v66.0/query/?q=SELECT+Name+FROM+Account',
            '{"totalSize":1, "done":true, "records":[{"attributes":{"type":"Account"}, "Name":"Ctorless"}]}'
        );
        Test.setMock(HttpCalloutMock.class, mock);
        SoqlQuery q = SoqlQuery.of('Account').field('Name').useDriver(new SoqlQuery.RestDriver('MyOrg'));

        // Act & Assert
        try {
            Test.startTest();
            q.fetchInto(List<NoDefaultCtorDto>.class);
            Test.stopTest();
            Assert.fail('Expected projection to fail for non-instantiable DTO');
        } catch (Exception e) {
            Test.stopTest();
            Assert.isTrue(e.getMessage().contains('Collection store exception'));
        }
    }
    // </editor-fold>

    // <editor-fold desc="SObjectCollectionsEngine">
    @IsTest
    static void should_throw_when_explain_called_on_sobject_collections_engine() {
        // Arrange
        Id id1 = fakeId(Account.SObjectType);
        SoqlQuery.SObjectCollectionsEngine engine = new SoqlQuery.SObjectCollectionsEngine();
        SoqlQuery.QueryArgs args = new SoqlQuery.QueryArgs(
            'SELECT Id FROM Account WHERE Id = :var$0',
            'SELECT Id FROM Account WHERE Id = \'' + id1 + '\'',
            new Map<String, Object>{ 'var$0' => id1 },
            AccessLevel.USER_MODE
        );
        args.listType = List<Map<String, Object>>.class;

        // Act & Assert
        Assert.areEqual('composite/sobjects', engine.resolveQueryResource(false));
        try {
            engine.explain(new SoqlQuery.RestDriver('MyOrg'), args);
            Assert.fail('Expected explain() to be unsupported');
        } catch (Query.QueryException e) {
            Assert.isTrue(e.getMessage().contains('does not support explain()'));
        }
    }

    @IsTest
    static void should_throw_when_sobject_collections_request_fails() {
        // Arrange
        Id id1 = fakeId(Account.SObjectType);
        MockCollectionsDriverError driver = new MockCollectionsDriverError();
        driver.useEngine(new SoqlQuery.SObjectCollectionsEngine());
        SoqlQuery q = SoqlQuery.of('Account')
            .fields('Id, Name')
            .addConditionIn('Id', new List<String>{ id1 })
            .useDriver(driver);

        // Act & Assert
        try {
            q.fetchInto(List<Map<String, Object>>.class);
            Assert.fail('Expected sObject Collections failure');
        } catch (Query.QueryException e) {
            Assert.isTrue(e.getMessage().contains('REST sObject Collections Failed: 400'));
        }
    }

    @IsTest
    static void should_parse_single_id_when_where_uses_equals() {
        // Arrange
        Id id1 = fakeId(Account.SObjectType);
        MockCollectionsDriver driver = new MockCollectionsDriver();
        driver.useEngine(new SoqlQuery.SObjectCollectionsEngine());
        SoqlQuery q = SoqlQuery.of('Account').fields('Id, Name').addConditionEq('Id', id1).useDriver(driver);

        // Act
        Test.startTest();
        List<Object> rows = q.fetchInto(List<Map<String, Object>>.class);
        Test.stopTest();

        // Assert
        Assert.areEqual(1, driver.requestedIdChunks.size());
        Assert.areEqual(1, driver.requestedIdChunks[0].size());
        Assert.areEqual(id1, driver.requestedIdChunks[0][0]);
        Assert.areEqual(1, rows.size());
    }
    // </editor-fold>

    // <editor-fold desc="BulkV2QueryEngine">
    @IsTest
    static void should_configure_bulk_engine_and_throw_on_explain() {
        // Arrange
        SoqlQuery.BulkV2QueryEngine engine = new SoqlQuery.BulkV2QueryEngine().setPollInterval(5).setCpuTimeout(50);
        SoqlQuery.QueryArgs args = new SoqlQuery.QueryArgs(
            'SELECT Id FROM Account',
            'SELECT Id FROM Account',
            new Map<String, Object>(),
            AccessLevel.USER_MODE
        );
        args.listType = List<Map<String, Object>>.class;

        // Act & Assert
        Assert.areEqual('jobs/query', engine.resolveQueryResource(false));
        try {
            engine.explain(new SoqlQuery.RestDriver('MyOrg'), args);
            Assert.fail('Expected explain() to be unsupported for bulk engine');
        } catch (Query.QueryException e) {
            Assert.isTrue(e.getMessage().contains('does not support explain()'));
        }
    }

    @IsTest
    static void should_throw_when_bulk_create_response_has_no_job_id() {
        // Arrange
        MockRest mock = new MockRest();
        mock.addResponse('/services/data/v66.0/jobs/query', '{}');
        Test.setMock(HttpCalloutMock.class, mock);
        SoqlQuery q = SoqlQuery.of('Account')
            .field('Id')
            .useDriver(new SoqlQuery.RestDriver('MyOrg').useEngine(new SoqlQuery.BulkV2QueryEngine()));

        // Act & Assert
        try {
            q.fetchInto(List<Map<String, Object>>.class);
            Assert.fail('Expected missing job id error');
        } catch (Query.QueryException e) {
            Assert.isTrue(e.getMessage().contains('missing job id'));
        }
    }

    @IsTest
    static void should_throw_when_bulk_job_state_is_failed() {
        // Arrange
        MockRest mock = new MockRest();
        mock.addResponse('/services/data/v66.0/jobs/query', '{"id":"750FAILED"}');
        mock.addResponse(
            '/services/data/v66.0/jobs/query/750FAILED',
            '{"id":"750FAILED","state":"Failed","errorMessage":"boom"}'
        );
        Test.setMock(HttpCalloutMock.class, mock);
        SoqlQuery q = SoqlQuery.of('Account')
            .field('Id')
            .useDriver(new SoqlQuery.RestDriver('MyOrg').useEngine(new SoqlQuery.BulkV2QueryEngine()));

        // Act & Assert
        try {
            q.fetchInto(List<Map<String, Object>>.class);
            Assert.fail('Expected bulk failed state error');
        } catch (Query.QueryException e) {
            Assert.isTrue(e.getMessage().contains('state=Failed'));
        }
    }

    @IsTest
    static void should_throw_when_bulk_status_request_returns_http_error() {
        // Arrange
        MockRest mock = new MockRest();
        mock.addResponse('/services/data/v66.0/jobs/query', '{"id":"750HTTPERR"}');
        mock.addError('/services/data/v66.0/jobs/query/750HTTPERR', 500, 'status failed');
        Test.setMock(HttpCalloutMock.class, mock);
        SoqlQuery q = SoqlQuery.of('Account')
            .field('Id')
            .useDriver(new SoqlQuery.RestDriver('MyOrg').useEngine(new SoqlQuery.BulkV2QueryEngine()));

        // Act & Assert
        try {
            q.fetchInto(List<Map<String, Object>>.class);
            Assert.fail('Expected bulk HTTP status error');
        } catch (Query.QueryException e) {
            Assert.isTrue(e.getMessage().contains('REST Bulk V2 Query status failed: 500'));
        }
    }

    @IsTest
    static void should_throw_when_bulk_poll_wait_exceeds_cpu_guard() {
        // Arrange
        MockRest mock = new MockRest();
        mock.addResponse('/services/data/v66.0/jobs/query', '{"id":"750INPROG"}');
        mock.addResponse('/services/data/v66.0/jobs/query/750INPROG', '{"id":"750INPROG","state":"InProgress"}');
        Test.setMock(HttpCalloutMock.class, mock);
        SoqlQuery.BulkV2QueryEngine engine = new SoqlQuery.BulkV2QueryEngine().setPollInterval(1000).setCpuTimeout(1);
        SoqlQuery q = SoqlQuery.of('Account')
            .field('Id')
            .useDriver(new SoqlQuery.RestDriver('MyOrg').useEngine(engine));

        // Act & Assert
        try {
            q.fetchInto(List<Map<String, Object>>.class);
            Assert.fail('Expected CPU guard error while waiting for next poll');
        } catch (Query.QueryException e) {
            Assert.isTrue(e.getMessage().contains('wait exceeded CPU guard'));
        }
    }

    @IsTest
    static void should_parse_bulk_csv_special_cases_when_projecting_rows() {
        // Arrange
        BulkEngineProbe probe = new BulkEngineProbe();
        String csv =
            String.fromCharArray(new List<Integer>{ 65279 }) +
            'Id,IsDeleted,Name' +
            '\r\n' +
            '001AAA,true,"A""B"' +
            '\r\n' +
            ',false,Raw';

        // Act
        List<List<String>> parsed = probe.parseCsvPublic(csv);
        List<Object> rows = probe.projectParsedRowsPublic(parsed, List<Map<String, Object>>.class, 'Account');
        List<Object> dtoRows = probe.projectParsedRowsPublic(parsed, List<QueryAccountDto>.class, 'Account');
        List<Object> emptyProjection = probe.projectParsedRowsPublic(
            new List<List<String>>(),
            List<Map<String, Object>>.class,
            'Account'
        );

        // Assert
        Assert.areEqual(2, rows.size());
        Map<String, Object> first = (Map<String, Object>) rows[0];
        Map<String, Object> second = (Map<String, Object>) rows[1];
        Assert.areEqual('true', first.get('IsDeleted'));
        Assert.areEqual('A"B', first.get('Name'));
        Assert.areEqual(null, second.get('Id'));
        Assert.areEqual('Raw', second.get('Name'));
        QueryAccountDto dto = (QueryAccountDto) dtoRows[0];
        Assert.areEqual(true, dto.IsDeleted);
        Assert.areEqual(0, emptyProjection.size());
    }
    // </editor-fold>

    // <editor-fold desc="QueryMoreEngine.COMPOSITE">
    @IsTest
    static void should_throw_when_composite_transport_returns_non_200() {
        // Arrange
        Map<String, Object> firstPage = page(new List<Object>(), false, '/next');
        MockRestDriverTransportError driver = new MockRestDriverTransportError(firstPage, true, false);
        driver.useEngine(
            new SoqlQuery.QueryEngine().setQueryMore(true).useQueryMoreEngine(SoqlQuery.QueryMoreEngine.COMPOSITE)
        );
        SoqlQuery q = SoqlQuery.of('Account').field('Id').useDriver(driver);

        // Act & Assert
        try {
            q.fetch();
            Assert.fail('Expected composite transport failure');
        } catch (Query.QueryException e) {
            Assert.isTrue(e.getMessage().contains('REST Composite Failed: 500'));
        }
    }
    // </editor-fold>

    // <editor-fold desc="QueryMoreEngine.COMPOSITE_BATCH">
    @IsTest
    static void should_throw_when_composite_batch_transport_returns_non_200() {
        // Arrange
        Map<String, Object> firstPage = page(new List<Object>(), false, '/next');
        MockRestDriverTransportError driver = new MockRestDriverTransportError(firstPage, false, true);
        driver.useEngine(
            new SoqlQuery.QueryEngine().setQueryMore(true).useQueryMoreEngine(SoqlQuery.QueryMoreEngine.COMPOSITE_BATCH)
        );
        SoqlQuery q = SoqlQuery.of('Account').field('Id').useDriver(driver);

        // Act & Assert
        try {
            q.fetch();
            Assert.fail('Expected composite batch transport failure');
        } catch (Query.QueryException e) {
            Assert.isTrue(e.getMessage().contains('REST Composite Batch Failed: 500'));
        }
    }
    // </editor-fold>

    // <editor-fold desc="QueryMoreIterator">
    @IsTest
    static void should_throw_when_query_more_iterator_next_is_called_without_elements() {
        // Arrange
        MockRestDriver driver = new MockRestDriver(page(new List<Object>(), true, null));
        SoqlQuery q = SoqlQuery.of('Account').field('Id').useDriver(driver);

        // Act & Assert
        try {
            q.fetchLazy().iterator().next();
            Assert.fail('Expected iterator next() to fail on empty result');
        } catch (Query.QueryException e) {
            Assert.isTrue(e.getMessage().contains('Iterator has no more elements'));
        }
    }

    @IsTest
    static void should_skip_null_child_relation_when_finalizing_sobject_metadata() {
        // Arrange
        Id id1 = fakeId(Account.SObjectType);
        Map<String, Object> root = new Map<String, Object>{
            'attributes' => new Map<String, Object>{ 'type' => 'Account' },
            'Id' => id1,
            'Name' => 'A',
            'Contacts' => null
        };
        MockRestDriver driver = new MockRestDriver(page(new List<Object>{ root }, true, null));
        SoqlQuery q = SoqlQuery.of('Account')
            .fields('Id, Name')
            .subQuery('Contacts', SoqlQuery.of('Contact').fields('Id, LastName'))
            .useDriver(driver);

        // Act
        Test.startTest();
        List<SObject> rows = q.fetch();
        Test.stopTest();

        // Assert
        Assert.areEqual(1, rows.size());
    }
    // </editor-fold>

    // <editor-fold desc="SObjectCollectionsIterator">
    @IsTest
    static void should_throw_when_sobject_collections_iterator_next_is_called_without_elements() {
        // Arrange
        Id id1 = fakeId(Account.SObjectType);
        MockCollectionsDriverEmpty driver = new MockCollectionsDriverEmpty();
        driver.useEngine(new SoqlQuery.SObjectCollectionsEngine());
        SoqlQuery q = SoqlQuery.of('Account').fields('Id, Name').addConditionEq('Id', id1).useDriver(driver);

        // Act & Assert
        try {
            q.fetchLazyInto(List<Map<String, Object>>.class).iterator().next();
            Assert.fail('Expected iterator next() to fail on empty sObject collections result');
        } catch (Query.QueryException e) {
            Assert.isTrue(e.getMessage().contains('Iterator has no more elements'));
        }
    }
    // </editor-fold>

    // <editor-fold desc="BulkV2Iterator">
    @IsTest
    static void should_throw_when_bulk_iterator_next_is_called_without_elements() {
        // Arrange
        MockRest mock = new MockRest();
        mock.addResponse('/services/data/v66.0/jobs/query', '{"id":"750EMPTY"}');
        mock.addResponse('/services/data/v66.0/jobs/query/750EMPTY', '{"id":"750EMPTY","state":"JobComplete"}');
        mock.addResponse('/services/data/v66.0/jobs/query/750EMPTY/results', '');
        Test.setMock(HttpCalloutMock.class, mock);
        SoqlQuery q = SoqlQuery.of('Account')
            .field('Id')
            .useDriver(new SoqlQuery.RestDriver('MyOrg').useEngine(new SoqlQuery.BulkV2QueryEngine()));

        // Act & Assert
        try {
            q.fetchLazyInto(List<Map<String, Object>>.class).iterator().next();
            Assert.fail('Expected iterator next() to fail on empty bulk result');
        } catch (Query.QueryException e) {
            Assert.isTrue(e.getMessage().contains('Iterator has no more elements'));
        }
    }
    // </editor-fold>

    // <editor-fold desc="Helpers">
    public static Id fakeId(SObjectType sObjectType) {
        String keyPrefix = sObjectType.getDescribe(SObjectDescribeOptions.DEFERRED).getKeyPrefix();
        return Id.valueOf(keyPrefix + '0'.repeat(12 - String.valueOf(count).length()) + count++);
    }

    private static Map<String, Object> page(List<Object> records, Boolean done, String nextRecordsUrl) {
        Map<String, Object> result = new Map<String, Object>{
            'totalSize' => records == null ? 0 : records.size(),
            'done' => done,
            'records' => records == null ? new List<Object>() : records
        };
        if (nextRecordsUrl != null) {
            result.put('nextRecordsUrl', nextRecordsUrl);
        }
        return result;
    }

    private static HttpResponse ok(Object body) {
        HttpResponse res = new HttpResponse();
        res.setStatusCode(200);
        res.setBody(JSON.serialize(body));
        return res;
    }

    private class MockRestDriver extends SoqlQuery.RestDriver {
        public Integer queryCalls = 0;
        public Integer compositeCalls = 0;
        public Integer compositeBatchCalls = 0;
        public final List<String> seenUrls = new List<String>();
        public final Map<String, Map<String, Object>> pagesByUrl = new Map<String, Map<String, Object>>();
        private final Map<String, Object> firstPage;

        private MockRestDriver(Map<String, Object> firstPage) {
            super('MockRest');
            this.firstPage = firstPage;
        }

        protected override HttpResponse send(HttpRequest req, String requestLabel) {
            String endpoint = req.getEndpoint();

            if (endpoint.endsWith('/composite')) {
                compositeCalls++;
                List<String> urls = new List<String>();
                Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(req.getBody());
                for (Object row : (List<Object>) payload.get('compositeRequest')) {
                    urls.add((String) ((Map<String, Object>) row).get('url'));
                }
                seenUrls.addAll(urls);

                List<Object> entries = new List<Object>();
                Integer i = 0;
                for (String url : urls) {
                    Map<String, Object> body = pagesByUrl.get(url);
                    Integer statusCode = body == null ? 404 : 200;
                    entries.add(
                        new Map<String, Object>{
                            'httpStatusCode' => statusCode,
                            'referenceId' => 'ref' + i++,
                            'body' => body == null ? new Map<String, Object>() : body
                        }
                    );
                }
                return RestDriverTest.ok(new Map<String, Object>{ 'compositeResponse' => entries });
            }

            if (endpoint.endsWith('/composite/batch')) {
                compositeBatchCalls++;
                List<String> urls = new List<String>();
                Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(req.getBody());
                for (Object row : (List<Object>) payload.get('batchRequests')) {
                    urls.add((String) ((Map<String, Object>) row).get('url'));
                }
                seenUrls.addAll(urls);

                List<Object> entries = new List<Object>();
                for (String url : urls) {
                    Map<String, Object> body = pagesByUrl.get(url);
                    Integer statusCode = body == null ? 404 : 200;
                    entries.add(
                        new Map<String, Object>{
                            'statusCode' => statusCode,
                            'result' => body == null ? new Map<String, Object>() : body
                        }
                    );
                }
                return RestDriverTest.ok(new Map<String, Object>{ 'hasErrors' => false, 'results' => entries });
            }

            queryCalls++;
            return RestDriverTest.ok(firstPage);
        }
    }

    private class MockCollectionsDriver extends SoqlQuery.RestDriver {
        public final List<String> endpoints = new List<String>();
        public final List<List<String>> requestedIdChunks = new List<List<String>>();
        public final List<Boolean> requestBodyHasFields = new List<Boolean>();

        private MockCollectionsDriver() {
            super('MockOrg');
        }

        protected override HttpResponse send(HttpRequest req, String requestLabel) {
            endpoints.add(req.getEndpoint());
            Map<String, Object> requestBody = (Map<String, Object>) JSON.deserializeUntyped(req.getBody());
            requestBodyHasFields.add(requestBody.containsKey('fields'));
            List<Object> ids = (List<Object>) requestBody.get('ids');
            List<String> chunk = new List<String>();
            List<Object> rows = new List<Object>();
            for (Object idObj : ids) {
                String id = String.valueOf(idObj);
                chunk.add(id);
                rows.add(
                    new Map<String, Object>{
                        'attributes' => new Map<String, Object>{ 'type' => 'Account' },
                        'Id' => id,
                        'Name' => 'Name-' + id
                    }
                );
            }
            requestedIdChunks.add(chunk);

            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(JSON.serialize(rows));
            return res;
        }
    }

    private class MockCollectionsDriverWithNull extends SoqlQuery.RestDriver {
        private final Id id;
        private MockCollectionsDriverWithNull(Id id) {
            super('MockOrg');
            this.id = id;
        }

        protected override HttpResponse send(HttpRequest req, String requestLabel) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                JSON.serialize(
                    new List<Object>{
                        null,
                        new Map<String, Object>{
                            'attributes' => new Map<String, Object>{ 'type' => 'Account' },
                            'Id' => id,
                            'Name' => 'Name-' + id
                        }
                    }
                )
            );
            return res;
        }
    }

    private class MockCollectionsDriverError extends SoqlQuery.RestDriver {
        private MockCollectionsDriverError() {
            super('MockOrg');
        }

        protected override HttpResponse send(HttpRequest req, String requestLabel) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(400);
            res.setBody('[{"message":"forced collections failure","errorCode":"BAD_REQUEST"}]');
            return res;
        }
    }

    private class MockCollectionsDriverEmpty extends SoqlQuery.RestDriver {
        private MockCollectionsDriverEmpty() {
            super('MockOrg');
        }

        protected override HttpResponse send(HttpRequest req, String requestLabel) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('[]');
            return res;
        }
    }

    private class MockRestDriverTransportError extends SoqlQuery.RestDriver {
        private final Map<String, Object> firstPage;
        private final Boolean failComposite;
        private final Boolean failBatch;

        private MockRestDriverTransportError(Map<String, Object> firstPage, Boolean failComposite, Boolean failBatch) {
            super('MockRest');
            this.firstPage = firstPage;
            this.failComposite = failComposite;
            this.failBatch = failBatch;
        }

        protected override HttpResponse send(HttpRequest req, String requestLabel) {
            HttpResponse res = new HttpResponse();
            String endpoint = req.getEndpoint();
            if (failComposite && endpoint.endsWith('/composite')) {
                res.setStatusCode(500);
                res.setBody('composite transport error');
                return res;
            }
            if (failBatch && endpoint.endsWith('/composite/batch')) {
                res.setStatusCode(500);
                res.setBody('batch transport error');
                return res;
            }
            res.setStatusCode(200);
            res.setBody(JSON.serialize(firstPage));
            return res;
        }
    }

    private class BulkEngineProbe extends SoqlQuery.BulkV2QueryEngine {
        public List<List<String>> parseCsvPublic(String csv) {
            return parseCsvByCharIndexes(csv);
        }

        public List<Object> projectParsedRowsPublic(List<List<String>> parsed, Type listType, String rootType) {
            return projectParsedRows(parsed, listType, rootType);
        }
    }

    private class NoDefaultCtorDto {
        public String Name;
        private NoDefaultCtorDto(String ignored) {
        }
    }

    private class MockRest implements HttpCalloutMock {
        private final Map<String, String> responses = new Map<String, String>();
        private final Map<String, Map<String, String>> responseHeadersByPath = new Map<String, Map<String, String>>();
        private final Map<String, Integer> errors = new Map<String, Integer>();
        private final Map<String, String> errorMessages = new Map<String, String>();
        private final Map<String, String> requestBodies = new Map<String, String>();
        public final Map<String, String> headers = new Map<String, String>();
        public Integer callCount = 0;

        public void addResponse(String path, String body) {
            responses.put(path, body);
        }

        public void addResponse(String path, String body, Map<String, String> responseHeaders) {
            responses.put(path, body);
            responseHeadersByPath.put(path, responseHeaders);
        }

        public void addError(String path, Integer code, String message) {
            errors.put(path, code);
            errorMessages.put(path, message);
        }

        public String getRequestBody(String path) {
            return requestBodies.get(path);
        }

        public Boolean hasRequestedPath(String path) {
            return requestBodies.containsKey(path);
        }

        public HttpResponse respond(HttpRequest req) {
            callCount++;
            for (String key : new List<String>{ 'Sforce-Query-Options' }) {
                if (req.getHeader(key) != null) {
                    headers.put(key, req.getHeader(key));
                }
            }
            String url = req.getEndpoint();

            if (url.endsWith('/composite')) {
                Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(req.getBody());
                List<Object> requests = (List<Object>) body.get('compositeRequest');
                List<Map<String, Object>> compositeResponse = new List<Map<String, Object>>();
                for (Object r : requests) {
                    Map<String, Object> reqMap = (Map<String, Object>) r;
                    String subUrl = (String) reqMap.get('url');
                    String referenceId = (String) reqMap.get('referenceId');

                    if (errors.containsKey(subUrl)) {
                        String message = errorMessages.containsKey(subUrl)
                            ? errorMessages.get(subUrl)
                            : 'Unknown composite error';
                        compositeResponse.add(
                            new Map<String, Object>{
                                'referenceId' => referenceId,
                                'httpStatusCode' => errors.get(subUrl),
                                'body' => new List<Object>{
                                    new Map<String, Object>{ 'errorCode' => 'MOCK_ERROR', 'message' => message }
                                }
                            }
                        );
                    } else {
                        Integer status = responses.containsKey(subUrl) ? 200 : 404;
                        String respBody = responses.get(subUrl);

                        compositeResponse.add(
                            new Map<String, Object>{
                                'referenceId' => referenceId,
                                'httpStatusCode' => status,
                                'body' => (status == 200) ? JSON.deserializeUntyped(respBody) : null
                            }
                        );
                    }
                }
                HttpResponse res = new HttpResponse();
                res.setStatusCode(200);
                res.setBody(JSON.serialize(new Map<String, Object>{ 'compositeResponse' => compositeResponse }));
                return res;
            }

            if (url.endsWith('/composite/batch')) {
                Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(req.getBody());
                List<Object> requests = (List<Object>) body.get('batchRequests');
                List<Map<String, Object>> results = new List<Map<String, Object>>();
                Boolean hasErrors = false;
                for (Object r : requests) {
                    Map<String, Object> reqMap = (Map<String, Object>) r;
                    String subUrl = (String) reqMap.get('url');

                    if (errors.containsKey(subUrl)) {
                        hasErrors = true;
                        String message = errorMessages.containsKey(subUrl)
                            ? errorMessages.get(subUrl)
                            : 'Unknown batch error';
                        results.add(
                            new Map<String, Object>{
                                'statusCode' => errors.get(subUrl),
                                'result' => new List<Object>{
                                    new Map<String, Object>{ 'errorCode' => 'MOCK_ERROR', 'message' => message }
                                }
                            }
                        );
                    } else {
                        Integer status = responses.containsKey(subUrl) ? 200 : 404;
                        String respBody = responses.get(subUrl);
                        results.add(
                            new Map<String, Object>{
                                'statusCode' => status,
                                'result' => (status == 200) ? JSON.deserializeUntyped(respBody) : null
                            }
                        );
                    }
                }
                HttpResponse res = new HttpResponse();
                res.setStatusCode(200);
                res.setBody(JSON.serialize(new Map<String, Object>{ 'hasErrors' => hasErrors, 'results' => results }));
                return res;
            }

            String path = url.substringAfter('MyOrg');
            requestBodies.put(path, req.getBody());

            HttpResponse res = new HttpResponse();
            if (errors.containsKey(path)) {
                res.setStatusCode(errors.get(path));
                res.setBody(errorMessages.get(path));
            } else if (responses.containsKey(path)) {
                res.setStatusCode(200);
                res.setBody(responses.get(path));
                if (responseHeadersByPath.containsKey(path)) {
                    for (String headerName : responseHeadersByPath.get(path).keySet()) {
                        res.setHeader(headerName, responseHeadersByPath.get(path).get(headerName));
                    }
                }
            } else {
                res.setStatusCode(404);
                res.setBody('Not Found: ' + path);
            }
            return res;
        }
    }

    private class MockRestEnvelopeCompat implements HttpCalloutMock {
        private final Map<String, String> responses = new Map<String, String>();
        private final Boolean forceBatchHasErrors;
        public Integer callCount = 0;

        private MockRestEnvelopeCompat(Boolean forceBatchHasErrors) {
            this.forceBatchHasErrors = forceBatchHasErrors;
        }

        public void addResponse(String path, String body) {
            responses.put(path, body);
        }

        public HttpResponse respond(HttpRequest req) {
            callCount++;
            String url = req.getEndpoint();
            if (url.endsWith('/composite')) {
                return respondComposite(req);
            }
            if (url.endsWith('/composite/batch')) {
                return respondBatch(req);
            }

            String path = url.substringAfter('MyOrg');
            HttpResponse res = new HttpResponse();
            if (responses.containsKey(path)) {
                res.setStatusCode(200);
                res.setBody(responses.get(path));
                return res;
            }
            res.setStatusCode(404);
            res.setBody('Not Found: ' + path);
            return res;
        }

        private HttpResponse respondComposite(HttpRequest req) {
            Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(req.getBody());
            List<Object> requests = (List<Object>) body.get('compositeRequest');
            List<Map<String, Object>> compositeResponse = new List<Map<String, Object>>();

            for (Object r : requests) {
                Map<String, Object> reqMap = (Map<String, Object>) r;
                String subUrl = (String) reqMap.get('url');
                String referenceId = (String) reqMap.get('referenceId');
                Integer status = responses.containsKey(subUrl) ? 200 : 404;
                Object payload = status == 200 ? JSON.deserializeUntyped(responses.get(subUrl)) : null;
                compositeResponse.add(
                    new Map<String, Object>{
                        'referenceId' => referenceId,
                        'httpStatusCode' => status,
                        'body' => payload
                    }
                );
            }

            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(JSON.serialize(new Map<String, Object>{ 'compositeResponse' => compositeResponse }));
            return res;
        }

        private HttpResponse respondBatch(HttpRequest req) {
            Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(req.getBody());
            List<Object> requests = (List<Object>) body.get('batchRequests');
            List<Map<String, Object>> compositeResponse = new List<Map<String, Object>>();
            List<Map<String, Object>> results = new List<Map<String, Object>>();

            Integer idx = 0;
            for (Object r : requests) {
                Map<String, Object> reqMap = (Map<String, Object>) r;
                String subUrl = (String) reqMap.get('url');
                Integer status = responses.containsKey(subUrl) ? 200 : 404;
                Object payload = status == 200 ? JSON.deserializeUntyped(responses.get(subUrl)) : null;
                compositeResponse.add(
                    new Map<String, Object>{
                        'referenceId' => 'ref' + idx,
                        'httpStatusCode' => status,
                        'body' => payload
                    }
                );
                results.add(new Map<String, Object>{ 'statusCode' => status, 'result' => payload });
                idx++;
            }

            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            Boolean hasErrors = forceBatchHasErrors == null ? false : forceBatchHasErrors;
            res.setBody(JSON.serialize(new Map<String, Object>{ 'hasErrors' => hasErrors, 'results' => results }));
            return res;
        }
    }
    // </editor-fold>
}
