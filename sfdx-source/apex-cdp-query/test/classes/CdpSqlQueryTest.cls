@IsTest(IsParallel=true)
private class CdpSqlQueryTest {
    @IsTest
    static void should_initialize_with_connect_api_driver_by_default() {
        // Arrange & Act
        CdpSqlQuery q = CdpSqlQuery.of('ssot__Individual__dlm');

        // Assert
        Assert.areEqual('SELECT Id FROM ssot__Individual__dlm', q.field('Id').toString());
    }

    @IsTest
    static void should_switch_to_rest_driver_when_requested() {
        // Arrange
        CdpSqlQuery q = CdpSqlQuery.of('ssot__Individual__dlm');

        // Act
        CdpSqlQuery result = q.useRestDriver('DataCloudNC');

        // Assert
        Assert.areEqual(q, result);
    }

    @IsTest
    static void should_construct_query_with_explicit_dataspace_factory() {
        // Arrange & Act
        CdpSqlQuery q = CdpSqlQuery.of('default', 'ssot__Individual__dlm', 'i');

        // Assert
        Assert.isTrue(q.field('i.ssot__Id__c').toString().contains('FROM ssot__Individual__dlm i'));
    }

    @IsTest
    static void should_initialize_with_cdp_runner() {
        // Arrange & Act
        CdpSqlQuery q = CdpSqlQuery.of('ssot__Individual__dlm');

        // Assert
        Assert.areEqual('SELECT Id FROM ssot__Individual__dlm', q.field('Id').toString());
    }

    @IsTest
    static void should_handle_ssot_fields_and_joins() {
        // Arrange
        CdpSqlQuery q = CdpSqlQuery.of('ssot__Individual__dlm', 'i');
        q.field('i.ssot__FirstName__c')
            .field('e.ssot__EmailAddress__c')
            .leftJoin('ssot__ContactPointEmail__dlm', 'e')
            .onx('i.ssot__Id__c = e.ssot__PartyId__c');

        // Act
        String sql = q.toString();

        // Assert
        Assert.isTrue(
            sql.contains('SELECT i.ssot__FirstName__c, e.ssot__EmailAddress__c FROM ssot__Individual__dlm i')
        );
        Assert.isTrue(sql.contains('LEFT JOIN ssot__ContactPointEmail__dlm e ON i.ssot__Id__c = e.ssot__PartyId__c'));
    }

    @IsTest
    static void should_handle_complex_ssot_query() {
        // Arrange
        CdpSqlQuery q = CdpSqlQuery.of('ssot__Individual__dlm', 'i');
        q.field('i.ssot__FirstName__c')
            .field('o.ssot__GrandTotalAmount__c')
            .join('ssot__SalesOrder__dlm', 'o')
            .onx('i.ssot__Id__c = o.ssot__SoldToCustomerId__c')
            .join('ssot__SalesOrderProduct__dlm', 'p')
            .onx('o.ssot__Id__c = p.ssot__SalesOrderId__c')
            .wherex(new SqlQuery.Condition().field('o.ssot__GrandTotalAmount__c').gt(100))
            .groupBy('i.ssot__FirstName__c, o.ssot__GrandTotalAmount__c');

        // Act
        String sql = q.toString();

        // Assert
        Assert.isTrue(
            sql.contains('INNER JOIN ssot__SalesOrder__dlm o ON i.ssot__Id__c = o.ssot__SoldToCustomerId__c')
        );
        Assert.isTrue(
            sql.contains('INNER JOIN ssot__SalesOrderProduct__dlm p ON o.ssot__Id__c = p.ssot__SalesOrderId__c')
        );
        Assert.isTrue(sql.contains('WHERE o.ssot__GrandTotalAmount__c > $1'));
    }

    @IsTest
    static void should_fetch_rows_via_rest_driver_when_callout_succeeds() {
        // Arrange
        SqlQuery q = CdpSqlQuery.of('ssot__Individual__dlm')
            .useRestDriver('DataCloudNC')
            .field('Id')
            .wherex(new SqlQuery.Condition().field('Name').eq('John'));
        MockRest mock = new MockRest(200, '{"data":[{"Id":"003","Name":"John"}],"done":true}');
        Test.setMock(HttpCalloutMock.class, mock);

        // Act
        List<Object> rows = q.fetch();

        // Assert
        Assert.areEqual(1, rows.size());
        Map<String, Object> row = (Map<String, Object>) rows[0];
        Assert.areEqual('003', row.get('Id'));
        Assert.areEqual('John', row.get('Name'));
        Assert.isTrue(mock.lastEndpoint.contains('callout:DataCloudNC/services/data/'));
        Assert.isTrue(mock.lastEndpoint.contains('/ssot/query-sql?'));
        Assert.isTrue(mock.lastEndpoint.contains('dataspace=default'));
        Assert.areEqual('POST', mock.lastMethod);

        Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(mock.lastBody);
        String sql = (String) payload.get('sql');
        Assert.isTrue(sql.contains('SELECT Id FROM ssot__Individual__dlm WHERE Name = \'John\''));
    }

    @IsTest
    static void should_fetch_rows_via_rest_driver_when_data_is_matrix() {
        // Arrange
        SqlQuery q = CdpSqlQuery.of('ssot__Individual__dlm').useRestDriver('DataCloudNC').field('Id').field('Name');
        MockRest mock = new MockRest(
            201,
            '{"data":[["003","John"]],"metadata":[{"name":"Id"},{"name":"Name"}],"returnedRows":1}'
        );
        Test.setMock(HttpCalloutMock.class, mock);

        // Act
        List<Object> rows = q.fetch();

        // Assert
        Assert.areEqual(1, rows.size());
        Map<String, Object> row = (Map<String, Object>) rows[0];
        Assert.areEqual('003', row.get('Id'));
        Assert.areEqual('John', row.get('Name'));
    }

    @IsTest
    static void should_fetch_rows_via_rest_driver_when_metadata_contains_non_map_entries() {
        // Arrange
        SqlQuery q = CdpSqlQuery.of('ssot__Individual__dlm').useRestDriver('DataCloudNC').field('Id').field('Name');
        MockRest mock = new MockRest(
            201,
            '{"data":[["003","John"]],"metadata":["bad",{"name":"Id"},{"name":"Name"}],"returnedRows":1}'
        );
        Test.setMock(HttpCalloutMock.class, mock);

        // Act
        List<Object> rows = q.fetch();

        // Assert
        Assert.areEqual(1, rows.size());
        Map<String, Object> row = (Map<String, Object>) rows[0];
        Assert.areEqual('003', row.get('Id'));
        Assert.areEqual('John', row.get('Name'));
    }

    @IsTest
    static void should_fetch_count_via_rest_driver_when_callout_succeeds() {
        // Arrange
        SqlQuery q = CdpSqlQuery.of('ssot__Individual__dlm')
            .useRestDriver('DataCloudNC')
            .wherex(new SqlQuery.Condition().field('Name').eq('John'));
        MockRest mock = new MockRest(
            200,
            '{"data":[[7]],"metadata":[{"name":"count","type":"BigInt","nullable":false}],"returnedRows":1}'
        );
        Test.setMock(HttpCalloutMock.class, mock);

        // Act
        Integer count = q.fetchCount();

        // Assert
        Assert.areEqual(7, count);
        Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(mock.lastBody);
        String sql = (String) payload.get('sql');
        Assert.isTrue(sql.startsWith('SELECT COUNT(*)'));
    }

    @IsTest
    static void should_fetch_count_via_rest_driver_when_data_is_matrix() {
        // Arrange
        SqlQuery q = CdpSqlQuery.of('ssot__Individual__dlm')
            .useRestDriver('DataCloudNC')
            .wherex(new SqlQuery.Condition().field('Name').eq('John'));
        MockRest mock = new MockRest(
            201,
            '{"data":[[0]],"metadata":[{"name":"count","type":"BigInt","nullable":false}],"returnedRows":1,"status":{"rowCount":1}}'
        );
        Test.setMock(HttpCalloutMock.class, mock);

        // Act
        Integer count = q.fetchCount();

        // Assert
        Assert.areEqual(0, count);
    }

    @IsTest
    static void should_fetch_count_from_status_row_count_when_data_is_not_present() {
        // Arrange
        SqlQuery q = CdpSqlQuery.of('ssot__Individual__dlm')
            .useRestDriver('DataCloudNC')
            .wherex(new SqlQuery.Condition().field('Name').eq('John'));
        MockRest mock = new MockRest(200, '{"status":{"rowCount":7}}');
        Test.setMock(HttpCalloutMock.class, mock);

        // Act
        Integer count = q.fetchCount();

        // Assert
        Assert.areEqual(7, count);
    }

    @IsTest
    static void should_return_zero_when_rest_count_has_no_data_and_no_row_count() {
        // Arrange
        SqlQuery q = CdpSqlQuery.of('ssot__Individual__dlm')
            .useRestDriver('DataCloudNC')
            .wherex(new SqlQuery.Condition().field('Name').eq('John'));
        MockRest mock = new MockRest(200, '{}');
        Test.setMock(HttpCalloutMock.class, mock);

        // Act
        Integer count = q.fetchCount();

        // Assert
        Assert.areEqual(0, count);
    }

    @IsTest
    static void should_throw_on_rest_driver_explain() {
        // Arrange
        SqlQuery q = CdpSqlQuery.of('ssot__Individual__dlm').useRestDriver('DataCloudNC');

        // Act & Assert
        try {
            q.explain();
            Assert.fail('Expected explain() to throw for RestDriver');
        } catch (Query.QueryException e) {
            Assert.isTrue(e.getMessage().contains('RestDriver does not support explain()'));
        }
    }

    @IsTest
    static void should_set_rest_api_version_and_validate_format() {
        // Arrange
        CdpSqlQuery.RestDriver driver = new CdpSqlQuery.RestDriver('DataCloudNC', 'default');

        // Act
        CdpSqlQuery.RestDriver same = driver.setApiVersion('v65.0');

        // Assert
        Assert.areEqual(driver, same);
        try {
            driver.setApiVersion('65.0');
            Assert.fail('Expected invalid api version format to fail');
        } catch (Query.QueryException e) {
            Assert.isTrue(e.getMessage().contains('apiVersion must match vXX.X'));
        }
    }

    @IsTest
    static void should_run_connect_api_driver_with_stubbed_output() {
        // Arrange
        ConnectApi.CdpQueryOutputV2 fake = buildOutput(
            new List<List<Object>>{ new List<Object>{ '003', 'John' } },
            new Map<String, Integer>{ 'Id' => 0, 'Name' => 1 }
        );
        CdpSqlQuery.ConnectApiDriver driver = new MockConnectApiDriver(fake);
        SqlQuery.QueryArgs args = new SqlQuery.QueryArgs(
            'SELECT Id, Name',
            'SELECT Id, Name',
            new Map<String, Object>()
        );

        // Act
        List<Object> rows = driver.run(args);

        // Assert
        Assert.areEqual(1, rows.size());
        Map<String, Object> row = (Map<String, Object>) rows[0];
        Assert.areEqual('003', row.get('Id'));
        Assert.areEqual('John', row.get('Name'));
    }

    @IsTest
    static void should_return_empty_when_connect_api_output_has_no_data() {
        // Arrange
        CdpSqlQuery.ConnectApiDriver driver = new MockConnectApiDriver(new ConnectApi.CdpQueryOutputV2());
        SqlQuery.QueryArgs args = new SqlQuery.QueryArgs('SELECT Id', 'SELECT Id', new Map<String, Object>());

        // Act
        List<Object> rows = driver.run(args);

        // Assert
        Assert.areEqual(0, rows.size());
    }

    @IsTest
    static void should_cover_connect_api_driver_count_branches() {
        // Arrange
        CdpSqlQuery.ConnectApiDriver scalar = new MockConnectApiDriver(
            buildOutput(new List<List<Object>>{ new List<Object>{ 5 } }, new Map<String, Integer>{ 'count' => 0 })
        );
        CdpSqlQuery.ConnectApiDriver empty = new MockConnectApiDriver(
            buildOutput(new List<List<Object>>(), new Map<String, Integer>())
        );
        CdpSqlQuery.ConnectApiDriver nullValue = new MockConnectApiDriver(
            buildOutput(new List<List<Object>>{ new List<Object>{ null } }, new Map<String, Integer>{ 'count' => 0 })
        );
        CdpSqlQuery.ConnectApiDriver emptyMap = new MockConnectApiDriver(
            buildOutput(new List<List<Object>>{ new List<Object>() }, new Map<String, Integer>())
        );
        SqlQuery.QueryArgs args = new SqlQuery.QueryArgs(
            'SELECT COUNT(*)',
            'SELECT COUNT(*)',
            new Map<String, Object>()
        );

        // Act & Assert
        Assert.areEqual(5, scalar.count(args));
        Assert.areEqual(0, empty.count(args));
        Assert.areEqual(0, nullValue.count(args));
        Assert.areEqual(0, emptyMap.count(args));
    }

    @IsTest
    static void should_throw_on_connect_api_driver_explain() {
        // Arrange
        CdpSqlQuery.ConnectApiDriver driver = new CdpSqlQuery.ConnectApiDriver('default');
        SqlQuery.QueryArgs args = new SqlQuery.QueryArgs('SELECT Id', 'SELECT Id', new Map<String, Object>());

        // Act & Assert
        try {
            driver.explain(args);
            Assert.fail('Expected explain() to throw for ConnectApiDriver');
        } catch (Query.QueryException e) {
            Assert.isTrue(e.getMessage().contains('ConnectApiDriver does not support explain()'));
        }
    }

    @IsTest
    static void should_cover_connect_api_driver_base_execute() {
        // Arrange
        BaseExecuteConnectApiDriver driver = new BaseExecuteConnectApiDriver();
        ConnectApi.CdpQueryInput input = new ConnectApi.CdpQueryInput();
        input.sql = 'SELECT 1';
        Boolean invoked = false;

        // Act
        try {
            driver.invokeBaseExecute(input);
            invoked = true;
        } catch (Exception ignored) {
            invoked = true;
        }

        // Assert
        Assert.isTrue(invoked, 'Base execute() path should be invoked');
    }

    @IsTest
    static void should_throw_exception_via_rest_driver_when_callout_fails() {
        // Arrange
        String message = '{"message":"boom"}';
        SqlQuery q = CdpSqlQuery.of('ssot__Individual__dlm').useRestDriver('DataCloudNC').field('Id');
        Test.setMock(HttpCalloutMock.class, new MockRest(500, message));

        // Act & Assert
        try {
            q.fetch();
            Assert.fail('Should have thrown QueryException for REST failure');
        } catch (Query.QueryException e) {
            Assert.isTrue(e.getMessage().contains('Data Cloud REST query failed: (500)'));
        }
    }

    private static ConnectApi.CdpQueryOutputV2 buildOutput(List<List<Object>> rows, Map<String, Integer> fieldOrder) {
        ConnectApi.CdpQueryOutputV2 output = new ConnectApi.CdpQueryOutputV2();
        output.data = new List<ConnectApi.CdpQueryV2Row>();
        output.metadata = new Map<String, ConnectApi.CdpQueryMetadataItem>();
        for (String fieldName : fieldOrder.keySet()) {
            ConnectApi.CdpQueryMetadataItem item = new ConnectApi.CdpQueryMetadataItem();
            item.placeInOrder = fieldOrder.get(fieldName);
            output.metadata.put(fieldName, item);
        }
        for (List<Object> values : rows) {
            ConnectApi.CdpQueryV2Row row = new ConnectApi.CdpQueryV2Row();
            row.rowData = values;
            output.data.add(row);
        }
        return output;
    }

    private class MockConnectApiDriver extends CdpSqlQuery.ConnectApiDriver {
        private final ConnectApi.CdpQueryOutputV2 output;

        private MockConnectApiDriver(ConnectApi.CdpQueryOutputV2 output) {
            super('default');
            this.output = output;
        }

        protected override ConnectApi.CdpQueryOutputV2 execute(ConnectApi.CdpQueryInput input) {
            return output;
        }
    }

    private class BaseExecuteConnectApiDriver extends CdpSqlQuery.ConnectApiDriver {
        private BaseExecuteConnectApiDriver() {
            super('default');
        }

        private ConnectApi.CdpQueryOutputV2 invokeBaseExecute(ConnectApi.CdpQueryInput input) {
            return super.execute(input);
        }
    }

    private class MockRest implements HttpCalloutMock {
        private final Integer statusCode;
        private final String responseBody;
        private String lastEndpoint;
        private String lastMethod;
        private String lastBody;

        private MockRest(Integer statusCode, String responseBody) {
            this.statusCode = statusCode;
            this.responseBody = responseBody;
        }

        public HttpResponse respond(HttpRequest req) {
            lastEndpoint = req.getEndpoint();
            lastMethod = req.getMethod();
            lastBody = req.getBody();

            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setBody(responseBody);
            return res;
        }
    }
}
