/**
 * Driver implementation for executing SQL queries against a public Datasette instance.
 */
public class DatasetteDriver implements SqlQuery.Driver {
    private final String endpoint;

    public DatasetteDriver(String endpoint) {
        // Ensure endpoint ends with .json to get JSON response
        if (!endpoint.endsWith('.json')) {
            throw new IllegalArgumentException('Endpoint must end with .json');
        }
        this.endpoint = endpoint;
    }

    public List<Object> run(SqlQuery.QueryArgs args) {
        String query = String.isNotBlank(args?.query) ? args.query : args?.inlineQuery;
        Map<String, Object> bindings = args?.bindings;

        // Datasette/SQLite binding safety:
        // 1. Inline numeric/boolean values because URL params are always strings,
        //    and SQLite comparison in HAVING/ORDER BY can fail against string types.
        // 2. Replace remaining ':var$' with '_var' for URL safety.
        Map<String, Object> cleanBindings = new Map<String, Object>();
        if (bindings != null) {
            for (String key : bindings.keySet()) {
                Object val = bindings.get(key);
                String placeholder = ':' + key.replace('$', '\\$');
                if (
                    val instanceof Integer ||
                    val instanceof Long ||
                    val instanceof Decimal ||
                    val instanceof Double ||
                    val instanceof Boolean
                ) {
                    query = query.replaceAll(placeholder + '(?![a-zA-Z0-9_])', String.valueOf(val));
                } else {
                    cleanBindings.put(key.replace('var$', 'var_'), val);
                }
            }
        }
        query = query.replaceAll(':var\\$', ':var_');

        String url = endpoint + '?sql=' + EncodingUtil.urlEncode(query, 'UTF-8');

        // Add remaining bindings as query parameters
        for (String key : cleanBindings.keySet()) {
            Object val = cleanBindings.get(key);
            String valStr = val == null ? '' : String.valueOf(val);
            url += '&' + EncodingUtil.urlEncode(key, 'UTF-8') + '=' + EncodingUtil.urlEncode(valStr, 'UTF-8');
        }

        // Force shape to be objects (List<Map<String, Object>>)
        url += '&_shape=objects';

        HttpRequest req = new HttpRequest();
        req.setEndpoint(url);
        req.setMethod('GET');
        req.setHeader('Accept', 'application/json');

        Http http = new Http();
        HttpResponse res = http.send(req);
        if (res.getStatusCode() != 200) {
            throw new CalloutException('Datasette query failed: ' + res.getStatus() + ' ' + res.getBody());
        }

        return parseResponse(res.getBody());
    }

    public Integer count(SqlQuery.QueryArgs args) {
        // Datasette usually returns a "rows" array. For count, we expect one row with one column.
        List<Object> rows = run(args);
        if (rows.isEmpty()) {
            return 0;
        }

        Object firstRow = rows[0];
        if (firstRow instanceof Map<String, Object>) {
            Map<String, Object> rowMap = (Map<String, Object>) firstRow;
            if (!rowMap.isEmpty()) {
                Object val = rowMap.values()[0];
                return Integer.valueOf(String.valueOf(val));
            }
        } else if (firstRow instanceof List<Object>) {
            List<Object> rowList = (List<Object>) firstRow;
            if (!rowList.isEmpty()) {
                return Integer.valueOf(String.valueOf(rowList[0]));
            }
        }

        return 0;
    }

    public Object explain(SqlQuery.QueryArgs args) {
        String query = String.isNotBlank(args?.query) ? args.query : args?.inlineQuery;
        SqlQuery.QueryArgs explainArgs = new SqlQuery.QueryArgs(
            'EXPLAIN QUERY PLAN ' + query,
            'EXPLAIN QUERY PLAN ' + query,
            args?.bindings
        );
        return run(explainArgs);
    }

    private List<Object> parseResponse(String jsonResponse) {
        Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(jsonResponse);
        if (root.containsKey('rows')) {
            return (List<Object>) root.get('rows');
        }
        return new List<Object>();
    }
}
