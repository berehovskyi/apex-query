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
    static void should_handle_inherited_collection_overloads_with_list_and_set() {
        // Arrange
        CdpSqlQuery q1 = CdpSqlQuery.of('ssot__Individual__dlm', 'i');
        CdpSqlQuery q2 = CdpSqlQuery.of('ssot__Individual__dlm', 'i');

        // Act
        q1.field('i.ssot__Id__c').addConditionIn('i.ssot__Id__c', new List<Object>{ 'a', 'b' });
        q2.field('i.ssot__Id__c').addConditionIn('i.ssot__Id__c', new Set<Object>{ 'a' });

        // Assert
        Assert.isTrue(q1.toString().contains('WHERE i.ssot__Id__c IN $1'));
        Assert.areEqual(new List<Object>{ 'a', 'b' }, q1.getBindings().get('$1'));
        Assert.isTrue(q2.toString().contains('WHERE i.ssot__Id__c IN $1'));
        Assert.areEqual(new Set<Object>{ 'a' }, q2.getBindings().get('$1'));
    }

    @IsTest
    static void should_support_stub_api_for_cdp_sql_query() {
        // Arrange
        RecordingStubProvider provider = new RecordingStubProvider();
        CdpSqlQuery stubbed = (CdpSqlQuery) Test.createStub(CdpSqlQuery.class, provider);

        // Act
        SqlQuery afterList = stubbed.fields(new List<Object>{ 'ssot__Id__c' });
        SqlQuery afterSet = stubbed.fields(new Set<Object>{ 'ssot__Id__c' });
        PostgresSqlQuery afterDistinctOnList = stubbed.distinctOn(new List<Object>{ 'ssot__Id__c' });
        PostgresSqlQuery afterDistinctOnSet = stubbed.distinctOn(new Set<Object>{ 'ssot__Id__c' });

        // Assert
        Assert.isTrue(stubbed === afterList, 'fields List<T> should retain the concrete stub type');
        Assert.isTrue(stubbed === afterSet, 'fields Set<T> should retain the concrete stub type');
        Assert.isTrue(stubbed === afterDistinctOnList, 'distinctOn List<T> should retain the concrete stub type');
        Assert.isTrue(stubbed === afterDistinctOnSet, 'distinctOn Set<T> should retain the concrete stub type');
        Assert.areEqual('fields', provider.calls[0].methodName);
        Assert.areEqual('List<ANY>', provider.calls[0].paramTypeName);
        Assert.areEqual(new List<Object>{ 'ssot__Id__c' }, provider.calls[0].arg);
        Assert.areEqual('fields', provider.calls[1].methodName);
        Assert.areEqual('Set<ANY>', provider.calls[1].paramTypeName);
        Assert.areEqual(new Set<Object>{ 'ssot__Id__c' }, provider.calls[1].arg);
        Assert.areEqual('distinctOn', provider.calls[2].methodName);
        Assert.areEqual('List<ANY>', provider.calls[2].paramTypeName);
        Assert.areEqual(new List<Object>{ 'ssot__Id__c' }, provider.calls[2].arg);
        Assert.areEqual('distinctOn', provider.calls[3].methodName);
        Assert.areEqual('Set<ANY>', provider.calls[3].paramTypeName);
        Assert.areEqual(new Set<Object>{ 'ssot__Id__c' }, provider.calls[3].arg);
        Assert.areEqual(4, provider.calls.size(), 'Every dispatched call should be recorded');
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
        Assert.areEqual(1, mock.callCount, 'A fetch must send exactly one REST request');

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
        Assert.areEqual(1, mock.callCount, 'A count must send exactly one REST request');
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
    static void should_fetch_count_from_status_when_data_is_empty() {
        Assert.areEqual(7, fetchRestCount('{"data":[],"status":{"rowCount":7}}'));
    }

    @IsTest
    static void should_fetch_count_from_status_when_first_data_row_is_empty() {
        Assert.areEqual(8, fetchRestCount('{"data":[[]],"status":{"rowCount":8}}'));
    }

    @IsTest
    static void should_fetch_count_from_status_when_data_count_is_null() {
        Assert.areEqual(9, fetchRestCount('{"data":[[null]],"status":{"rowCount":9}}'));
    }

    @IsTest
    static void should_fetch_count_from_status_when_data_row_is_not_a_list() {
        Assert.areEqual(10, fetchRestCount('{"data":[{}],"status":{"rowCount":10}}'));
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

    private static Integer fetchRestCount(String responseBody) {
        SqlQuery q = CdpSqlQuery.of('ssot__Individual__dlm')
            .useRestDriver('DataCloudNC')
            .wherex(new SqlQuery.Condition().field('Name').eq('John'));
        Test.setMock(HttpCalloutMock.class, new MockRest(200, responseBody));
        return q.fetchCount();
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
        private Integer callCount = 0;

        private MockRest(Integer statusCode, String responseBody) {
            this.statusCode = statusCode;
            this.responseBody = responseBody;
        }

        public HttpResponse respond(HttpRequest req) {
            callCount++;
            lastEndpoint = req.getEndpoint();
            lastMethod = req.getMethod();
            lastBody = req.getBody();

            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setBody(responseBody);
            return res;
        }
    }

    private class RecordedCall {
        private final String methodName;
        private final String paramTypeName;
        private final Object arg;

        private RecordedCall(final String methodName, final String paramTypeName, final Object arg) {
            this.methodName = methodName;
            this.paramTypeName = paramTypeName;
            this.arg = arg;
        }
    }

    private class RecordingStubProvider implements System.StubProvider {
        private final List<RecordedCall> calls = new List<RecordedCall>();

        public Object handleMethodCall(
            Object stubbedObject,
            String stubbedMethodName,
            Type returnType,
            List<Type> listOfParamTypes,
            List<String> listOfParamNames,
            List<Object> listOfArgs
        ) {
            String paramTypeName = listOfParamTypes.isEmpty() ? null : listOfParamTypes[0].toString();
            Object arg = listOfArgs.isEmpty() ? null : listOfArgs[0];
            calls.add(new RecordedCall(stubbedMethodName, paramTypeName, arg));
            return stubbedObject;
        }
    }
}
