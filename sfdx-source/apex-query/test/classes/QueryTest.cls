@IsTest(IsParallel=true)
private class QueryTest {
    @IsTest
    static void should_format_value() {
        // Arrange
        Date d = Date.newInstance(2023, 1, 15);
        Datetime dt = Datetime.newInstanceGmt(2023, 1, 15, 12, 0, 0);
        Time t = Time.newInstance(12, 30, 45, 0);
        String s = 'test string';
        String escaped = 'O\'Reilly';
        List<Object> listVal = new List<Object>{ 'a', 1, true };

        // Act & Assert
        Assert.areEqual('NULL', Query.formatValue(null), 'Should format null');
        Assert.areEqual('TRUE', Query.formatValue(true), 'Should format boolean true');
        Assert.areEqual('FALSE', Query.formatValue(false), 'Should format boolean false');
        Assert.areEqual('\'2023-01-15\'', Query.formatValue(d), 'Should format Date');
        Assert.areEqual('\'2023-01-15T12:00:00Z\'', Query.formatValue(dt), 'Should format Datetime');
        Assert.areEqual('\'12:30:45.000Z\'', Query.formatValue(t), 'Should format Time');
        Assert.areEqual('\'test string\'', Query.formatValue(s), 'Should format String');
        Assert.areEqual('\'O\\\'Reilly\'', Query.formatValue(escaped), 'Should escape single quotes in String');
        Assert.areEqual(
            '(\'a\', 1, TRUE)',
            Query.formatValue(listVal),
            'Should format Iterable as comma-separated list'
        );
        Assert.areEqual('123', Query.formatValue(123), 'Should format Integer/Decimal via toString');
        Assert.areEqual('123.45', Query.formatValue(123.45), 'Should format Decimal');
    }

    @IsTest
    static void should_return_elapsed_time_when_timer_elapsed_is_called() {
        // Arrange
        Long start = Query.timerStart(Query.Timer.SYS);

        // Act
        Long elapsed = Query.timerElapsed(Query.Timer.SYS, start);

        // Assert
        Assert.isTrue(elapsed >= 0, 'Elapsed timer should be non-negative');
    }
}
