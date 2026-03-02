/**
 * Data Cloud (CDP) specific implementation of SqlQuery.
 *
 * Encapsulates two execution drivers:
 * - `ConnectApiDriver` (default) for `ConnectApi.CdpQuery.queryAnsiSqlV2`
 * - `RestDriver` for `/services/data/vXX.X/ssot/query-sql`
 *
 * Warning: `ConnectApiDriver` returns raw Data Cloud values and can emit datetime strings
 * in formats that don't deserialize into typed SObject fields. For typed SObject projection,
 * prefer `useRestDriver(...)` or use DTO/untyped targets.
 *
 * @example
 * List<Object> rows = CdpSqlQuery.of('ssot__Account__dlm', 'a')
 *     .field('a.ssot__Id__c', 'account_id')
 *     .field('a.ssot__Name__c', 'account_name')
 *     .lim(5)
 *     .fetch();
 *
 * List<ssot__Account__dlm> rows = (List<ssot__Account__dlm>) CdpSqlQuery.of('ssot__Account__dlm', 'a')
 *     .useRestDriver('DataCloud')
 *     .field('a.ssot__Id__c', 'account_id')
 *     .field('a.ssot__Name__c', 'account_name')
 *     .lim(5)
 *     .fetchInto(List<ssot__Account__dlm>.class);
 */
public virtual inherited sharing class CdpSqlQuery extends PostgresSqlQuery {
    protected final String dataspace;

    public CdpSqlQuery(final String table) {
        this(table, '');
    }

    public CdpSqlQuery(final String table, final String alias) {
        this('default', table, alias);
    }

    public CdpSqlQuery(final String dataspace, final String table, final String alias) {
        super(table, alias);
        validateNotBlank(dataspace, 'dataspace');
        this.dataspace = dataspace;
        driver = new ConnectApiDriver(dataspace);
    }

    public static CdpSqlQuery of(final String table) {
        return new CdpSqlQuery(table);
    }

    public static CdpSqlQuery of(final String table, final String alias) {
        return new CdpSqlQuery(table, alias);
    }

    public static CdpSqlQuery of(final String dataspace, final String table, final String alias) {
        return new CdpSqlQuery(dataspace, table, alias);
    }

    public CdpSqlQuery useRestDriver(final String namedCredential) {
        driver = new RestDriver(namedCredential, dataspace);
        return this;
    }

    private abstract class BaseDriver implements Driver {
        protected final String dataspace;
        protected Boolean isDebugEnabled = false;
        protected Boolean isTimerEnabled = false;
        protected Query.Timer timerMode = Query.Timer.SYS;

        protected BaseDriver(final String dataspace) {
            validateNotBlank(dataspace, 'dataspace');
            this.dataspace = dataspace;
        }

        protected void applyExecutionArgs(final QueryArgs args) {
            isDebugEnabled = args.isDebugEnabled ?? false;
            isTimerEnabled = args.isTimerEnabled ?? false;
            timerMode = args.timerMode ?? Query.Timer.SYS;
        }
    }

    /**
     * Driver that executes Data Cloud SQL through ConnectApi.
     * Best for simple untyped projections.
     */
    public virtual class ConnectApiDriver extends BaseDriver {
        /**
         * Creates a ConnectApi driver for a specific dataspace.
         * @param dataspace Data Cloud dataspace name
         */
        public ConnectApiDriver(final String dataspace) {
            super(dataspace);
        }

        /**
         * Executes ANSI SQL via ConnectApi and returns untyped row maps.
         * Warning: output values are returned as provided by Data Cloud and may include
         * datetime strings that are not JSON/SObject-deserialization friendly.
         * Prefer `RestDriver` for typed SObject projection.
         * @param args Compiled SQL query arguments
         * @return List of untyped row maps
         */
        @SuppressWarnings('PMD.AvoidDebugStatements')
        public List<Object> run(final QueryArgs args) {
            applyExecutionArgs(args);
            ConnectApi.CdpQueryInput input = new ConnectApi.CdpQueryInput();
            input.sql = args.inlineQuery;
            if (isDebugEnabled ?? false) {
                System.debug(LoggingLevel.ERROR, 'cdp.run: ' + input.sql);
            }
            final Long start = timerStart(timerMode);
            ConnectApi.CdpQueryOutputV2 output = execute(input);
            logTimer(isTimerEnabled, timerMode, 'cdp.run', start);
            return parseOutput(output);
        }

        protected virtual ConnectApi.CdpQueryOutputV2 execute(final ConnectApi.CdpQueryInput input) {
            return ConnectApi.CdpQuery.queryAnsiSqlV2(input, dataspace);
        }

        /**
         * Executes a COUNT query and extracts the first scalar value.
         * @param args Compiled SQL query arguments
         * @return Count value or 0 when no rows are returned
         */
        public Integer count(final QueryArgs args) {
            List<Object> rows = run(args);
            if (rows?.isEmpty() ?? true) {
                return 0;
            }
            Object first = rows[0];
            Object countValue = first;
            if (first instanceof Map<String, Object>) {
                Map<String, Object> row = (Map<String, Object>) first;
                if (row.isEmpty()) {
                    return 0;
                }
                countValue = row.values()[0];
            }
            if (countValue == null) {
                return 0;
            }
            return Integer.valueOf(countValue);
        }

        /**
         * Explain is currently unsupported for ConnectApi execution.
         * @param args Compiled SQL query arguments
         * @return Never returns successfully
         * @throws QueryException Always thrown.
         */
        public Object explain(final QueryArgs args) {
            throw new QueryException('ConnectApiDriver does not support explain()');
        }

        @SuppressWarnings('PMD.OneDeclarationPerLine')
        private List<Object> parseOutput(ConnectApi.CdpQueryOutputV2 output) {
            List<Object> results = new List<Object>();
            if (output?.data == null || output?.metadata == null) {
                return results;
            }
            List<String> fields = new List<String>(output.metadata.size());
            for (String field : output.metadata.keySet()) {
                Integer index = output.metadata.get(field).placeInOrder;
                fields[index] = field;
            }
            for (ConnectApi.CdpQueryV2Row row : output.data) {
                Map<String, Object> record = new Map<String, Object>();
                for (Integer i = 0, size = fields.size(); i < size; i++) {
                    record.put(fields[i], row.rowData[i]);
                }
                results.add(record);
            }
            return results;
        }
    }

    /**
     * Driver that executes Data Cloud SQL over REST callouts through a Named Credential.
     */
    public virtual class RestDriver extends BaseDriver {
        protected final Pattern apiVersionPattern = Pattern.compile('(?i)^v\\d{2}\\.\\d$');
        protected final String namedCredential;
        protected String apiVersion = 'v66.0';

        /**
         * Creates a REST driver for a named credential and dataspace.
         * @param namedCredential Named Credential used for callouts
         * @param dataspace Data Cloud dataspace name
         */
        public RestDriver(final String namedCredential, final String dataspace) {
            super(dataspace);
            validateNotBlank(namedCredential, 'namedCredential');
            this.namedCredential = namedCredential;
        }

        /**
         * Sets REST API version for callout path.
         * @param apiVersion Version in format `vXX.X` (example: `v66.0`)
         * @return This driver instance
         */
        public RestDriver setApiVersion(String apiVersion) {
            validateNotBlank(apiVersion, 'apiVersion');
            String requested = apiVersion.trim().toLowerCase();
            validateIsTrue(
                apiVersionPattern.matcher(requested).matches(),
                'apiVersion must match vXX.X (example: v66.0). Value: ' + apiVersion
            );
            this.apiVersion = requested;
            return this;
        }

        /**
         * Executes SQL over REST and returns row maps.
         * @param args Compiled SQL query arguments
         * @return List of row maps
         */
        public List<Object> run(QueryArgs args) {
            applyExecutionArgs(args);
            HttpResponse res = sendRequest(args);
            return parseResponse(res.getBody());
        }

        /**
         * Executes a COUNT query over REST.
         * @param args Compiled SQL query arguments
         * @return Count value from `data` or status row count fallback
         */
        public Integer count(QueryArgs args) {
            applyExecutionArgs(args);
            HttpResponse res = sendRequest(args);
            Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            Integer fromRows = extractCountFromRows(root);
            if (fromRows != null) {
                return fromRows;
            }
            if (root.containsKey('status') && root.get('status') instanceof Map<String, Object>) {
                Map<String, Object> status = (Map<String, Object>) root.get('status');
                if (status.containsKey('rowCount')) {
                    return (Integer) status.get('rowCount');
                }
            }
            return 0;
        }

        /**
         * Explain is currently unsupported for REST execution.
         * @param args Compiled SQL query arguments
         * @return Never returns successfully
         * @throws QueryException Always thrown.
         */
        public Object explain(QueryArgs args) {
            throw new QueryException('RestDriver does not support explain()');
        }

        protected virtual HttpResponse sendRequest(QueryArgs args) {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(
                'callout:' +
                    namedCredential +
                    '/services/data/' +
                    apiVersion +
                    '/ssot/query-sql' +
                    '?dataspace=' +
                    EncodingUtil.urlEncode(dataspace, 'UTF-8')
            );
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setBody(JSON.serialize(new Map<String, Object>{ 'sql' => args.inlineQuery }));
            send(req, 'queryRequest');
            HttpResponse res = send(req, 'queryRequest');
            final Integer code = res.getStatusCode();
            if (code < 200 || code >= 300) {
                throw new QueryException(
                    'Data Cloud REST query failed: (' + res.getStatusCode() + ') ' + res.getBody()
                );
            }
            return res;
        }

        protected virtual HttpResponse send(final HttpRequest req, final String requestLabel) {
            logRequest(isDebugEnabled, req, requestLabel);
            final Long start = timerStart(timerMode);
            final HttpResponse res = new Http().send(req);
            logTimer(isTimerEnabled, timerMode, requestLabel, start);
            return res;
        }

        private Integer extractCountFromRows(Map<String, Object> root) {
            if (!(root.containsKey('data') && root.get('data') instanceof List<Object>)) {
                return null;
            }
            List<Object> rows = (List<Object>) root.get('data');
            List<Object> row = (List<Object>) rows[0];
            return Integer.valueOf(String.valueOf(row[0]));
        }

        private List<Object> parseResponse(String responseBody) {
            Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
            List<Object> rows = (List<Object>) root.get('data') ?? new List<Object>();
            if (rows.isEmpty() || rows[0] instanceof Map<String, Object>) {
                return rows;
            }
            List<String> fields = new List<String>();
            if (root.containsKey('metadata') && root.get('metadata') instanceof List<Object>) {
                for (Object metaObj : (List<Object>) root.get('metadata')) {
                    if (!(metaObj instanceof Map<String, Object>)) {
                        continue;
                    }
                    Map<String, Object> meta = (Map<String, Object>) metaObj;
                    String name = String.valueOf(meta.get('name'));
                    fields.add(String.isNotBlank(name) ? name : 'col' + fields.size());
                }
            }
            List<Object> projected = new List<Object>();
            for (Object rowObj : rows) {
                List<Object> values = (List<Object>) rowObj;
                Map<String, Object> record = new Map<String, Object>();
                for (Integer i = 0; i < values.size(); i++) {
                    String key = i < fields.size() ? fields[i] : 'col' + i;
                    record.put(key, values[i]);
                }
                projected.add(record);
            }
            return projected;
        }
    }
}
