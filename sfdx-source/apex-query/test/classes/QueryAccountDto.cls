@IsTest
public class QueryAccountDto {
    public Attributes attributes;
    public String Id;
    public Boolean IsDeleted;
    public String MasterRecordId;
    public String Name;
    public String Type;
    public String ParentId;
    public String BillingStreet;
    public String BillingCity;
    public String BillingState;
    public String BillingPostalCode;
    public String BillingCountry;
    public Double BillingLatitude;
    public Double BillingLongitude;
    public String BillingGeocodeAccuracy;
    public Address BillingAddress;
    public String ShippingStreet;
    public String ShippingCity;
    public String ShippingState;
    public String ShippingPostalCode;
    public String ShippingCountry;
    public Double ShippingLatitude;
    public Double ShippingLongitude;
    public String ShippingGeocodeAccuracy;
    public Address ShippingAddress;
    public String Phone;
    public String Fax;
    public String AccountNumber;
    public String Website;
    public String PhotoUrl;
    public String Sic;
    public String Industry;
    public Double AnnualRevenue;
    public Integer NumberOfEmployees;
    public String Ownership;
    public String TickerSymbol;
    public String Description;
    public String Rating;
    public String Site;
    public String CurrencyIsoCode;
    public String OwnerId;
    public Datetime CreatedDate;
    public String CreatedById;
    public Datetime LastModifiedDate;
    public String LastModifiedById;
    public Datetime SystemModstamp;
    public Date LastActivityDate;
    public Datetime LastViewedDate;
    public Datetime LastReferencedDate;
    public String Jigsaw;
    public String JigsawCompanyId;
    public String CleanStatus;
    public String AccountSource;
    public String DunsNumber;
    public String Tradestyle;
    public String NaicsCode;
    public String NaicsDesc;
    public String YearStarted;
    public String SicDesc;
    public String DandbCompanyId;
    public String OperatingHoursId;

    // Apex prohibits double underscores in class members. Any Salesforce double-underscore (__, __c, __r, __pc)
    // is automatically normalized to single-underscore by SoqlQuery during Dto hydration.
    public String ExternalId_c;
    public String Interests_c;
    public QueryResultsContacts Owner_r; // testing __r -> _r
    public UserDto Owner; // testing __r -> _r
    public String PersonContactId_pc; // testing __pc -> _pc

    public QueryResultsCases Cases;
    public QueryResultsContacts Contacts;
    public QueryResultsTasks Tasks;

    public virtual class SObjectDto {
        public Attributes attributes;
        public String Id;
        public String Name;
    }

    public class Attributes {
        public String type;
        public String url;
    }

    public class Address {
        public String city;
        public String geocodeAccuracy;
        public String country;
        public String state;
        public String street;
        public String postalCode;
        public Double latitude;
        public Double longitude;
    }

    public class QueryResultsCases {
        public Integer totalSize;
        public Boolean done;
        public List<QueryCaseDto> records;
    }

    public class QueryCaseDto extends SObjectDto {
        public String CaseNumber;
        public String Origin;
    }

    public class QueryResultsContacts {
        public Integer totalSize;
        public Boolean done;
        public List<QueryContactDto> records;
    }

    public class QueryContactDto extends SObjectDto {
        public String LastName;
        public String AccountId;
    }

    public class QueryResultsTasks {
        public Integer totalSize;
        public Boolean done;
        public List<QueryTaskDto> records;
    }

    public class QueryTaskDto extends SObjectDto {
        public QueryResultsFeeds Feeds;
    }

    public class QueryResultsFeeds {
        public Integer totalSize;
        public Boolean done;
        public List<QueryFeedDto> records;
    }

    public class QueryFeedDto extends SObjectDto {
        public String Title;
        public String Type;
        public String BestCommentId;
    }

    public class UserDto extends SObjectDto {
        public ProfileDto Profile;
    }

    public class ProfileDto extends SObjectDto {
        public UserLicenseDto UserLicense;
    }

    public class UserLicenseDto extends SObjectDto {
    }
}
