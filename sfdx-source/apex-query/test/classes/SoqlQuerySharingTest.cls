@IsTest(IsParallel=false)
private class SoqlQuerySharingTest {
    @IsTest
    static void should_enforce_with_sharing_when_called_from_without_sharing_context() {
        // Arrange
        Event source = sourceEvent();
        User owner = standardUser();
        User reader = standardUser();
        System.runAs(owner) {
            insert source;
        }
        List<SObject> records;

        // Act
        System.runAs(reader) {
            records = new WithoutSharingCaller().fetchWithSharing(source.Id);
        }

        // Assert
        Assert.areEqual(0, records.size());
    }

    @IsTest
    static void should_bypass_sharing_when_called_from_with_sharing_context() {
        // Arrange
        Event source = sourceEvent();
        User owner = standardUser();
        User reader = standardUser();
        System.runAs(owner) {
            insert source;
        }
        List<SObject> records;

        // Act
        System.runAs(reader) {
            records = new WithSharingCaller().fetchWithoutSharing(source.Id);
        }

        // Assert
        Assert.areEqual(1, records.size());
        Assert.areEqual(source.Id, records[0].get('Id'));
    }

    private static Event sourceEvent() {
        Datetime startTime = System.now().addDays(1);
        return new Event(Subject = 'Sharing Probe', StartDateTime = startTime, EndDateTime = startTime.addHours(1));
    }

    private static User standardUser() {
        String uniqueName = 'apex.query.sharing.' + System.UUID.randomUUID();
        return new User(
            Alias = 'qryshare',
            Email = uniqueName + '@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Apex Query Sharing User',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            Profile = new Profile(Name = 'Standard User'),
            TimeZoneSidKey = 'America/Los_Angeles',
            Username = uniqueName + '@example.com'
        );
    }

    private with sharing class WithSharingCaller {
        private List<SObject> fetchWithoutSharing(final Id recordId) {
            return SoqlQuery.of(Event.SObjectType)
                .field(Event.Id)
                .addConditionEq(Event.Id, recordId)
                .withoutSharing()
                .withSystemMode()
                .fetch();
        }
    }

    private without sharing class WithoutSharingCaller {
        private List<SObject> fetchWithSharing(final Id recordId) {
            return SoqlQuery.of(Event.SObjectType)
                .field(Event.Id)
                .addConditionEq(Event.Id, recordId)
                .withSharing()
                .withSystemMode()
                .fetch();
        }
    }
}
