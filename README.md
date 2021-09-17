# Time Travel

The time travel gem adds in-table version control to your data. It lets you see, correct and update records at any point in time, but preserves the entire history of corrections and updates to your data so you can drill-down and find out exactly what happened when something goes wrong.

# How It Works

Lets say that we're a new bank and we're planning to maintain our customers' cash balances in a table called `balance`.

We first add time travel fields to the model with
```
> bundle exec rake generate time_travel balance
> bundle exec rake db:migrate
```
include the Time Travel helper in the `balance` model

```
class Balance < ActiveRecord::Base
  include TimeTravel::TimelineHelper
  
  ...
```
and define the `timeline_fields` method to return the fields that uniquely identify each timeline in our model(in our case, the cash account id)
```
  ...
  def self.timeline_fields
    :cash_account_id
  end
```

Then we start off our operations

## Day 1 - 6th Septermber - New Account

The operations team informs us that a new customer created our bank's first account and deposited $500 5 days ago

We record this info with

```
> timeline=balance.timeline(cash_account_id: 1)
> timeline.create(amount: 500, effective_from: Time.now - 5.days)
```

After a few minutes, they ping us again and tells us that the customer also submitted an additional $200 two days ago,
so we record that as well with

```
# the new balance is 500+200, which is $700
> timeline.update(amount: 700, effective_from: Time.now - 2.days)
```

## Day 2 - 7th September - Corrections

An operations guy walks in hurriedly and tells us that they are extremely sorry but the amounts deposited were recorded wrong, it was $600 and $300 and not $500 and $200

We cross-check with the team and record the updates
```
> timeline.update(amount: 600, effective_from: Time.now - 6 days)
> timeline.update(amount: 900, effective_from: Time.now - 3.days)
```

## Day 3 - 8th September - Reconcilliation

On day 3, the customer walks in and tells us that something is wrong with our systems and that the balances were different yesterday and day-before even though he didn't deposit or withdraw any money

So our support team starts with checking the current balance first

To decipher what happened, the team looks at two time ranges in each record. The effective time range(`effective_from` and `effective_till`) tells them what period the data was recorded for, while the valid time range(`valid_from` and `valid_till`) tells them when the data was recorded. An infinite end date(1-1-3000) tells them that the record is currently effective or currently valid depending on which time range it shows up on.

```
> timeline.at(Time.now)
{
  "id"=>6,
  "cash_account_id"=>1,
  "amount"=>900,
  "reference_id"=>nil,
  "effective_from"=>"2021-09-04T18:30:00.000Z",
  "effective_till"=>"3000-01-01T00:00:00.000Z",
  "valid_from"=>"2021-09-07T18:30:00.000Z",
  "valid_till"=>"3000-01-01T00:00:00.000Z"
}
```
The above record tells them that the customer's balance changed to $900 on the 4th of September and is currently effective, and that the amount was recorded on the 7th and is currently valid.

They check if the customer expects the balance to be $900 and he confirms this

Great, atleast the current balance in order, so they start digging in deeper to check what the balance was 2 days ago

```
> timeline.at(Time.now - 2.days, as_of: Time.now - 2.days)
{
  "id"=>3,
  "cash_account_id"=>1,
  "amount"=>700,
  "reference_id"=>nil,
  "effective_from"=>"2021-09-04T18:30:00.000Z",
  "effective_till"=>"3000-01-01T00:00:00.000Z",
  "valid_from"=>"2021-09-06T18:30:00.000Z",
  "valid_till"=>"2021-09-07T18:30:00.000Z"
}
```
They realize from this record is that the balance was indeed different two days ago, and it reflected $700. Additionally the valid time range tells them that there was a correction made to the balance a day later since the valid time range ends on the 7th.

They inform the customer that two days ago, he might have seen a balance of $700, and he confirms this.

They then check further and compare balance data recorded two days ago to find out what happened

```
> timeline.as_of(Time.now - 2.days)
[
  {
    "id"=>2,
    "cash_account_id"=>1,
    "amount"=>500,
    "reference_id"=>nil,
    "effective_from"=>"2021-09-01T18:30:00.000Z",
    "effective_till"=>"2021-09-04T18:30:00.000Z",
    "valid_from"=>"2021-09-06T18:30:00.000Z",
    "valid_till"=>"2021-09-07T18:30:00.000Z"
  },
  {
    "id"=>3,
    "cash_account_id"=>1,
    "amount"=>700,
    "reference_id"=>nil,
    "effective_from"=>"2021-09-04T18:30:00.000Z",
    "effective_till"=>"3000-01-01T00:00:00.000Z",
    "valid_from"=>"2021-09-06T18:30:00.000Z",
    "valid_till"=>"2021-09-07T18:30:00.000Z"
  }
]

> timeline.as_of(Time.now)
[
  {
    "id"=>5,
    "cash_account_id"=>1,
    "amount"=>600,
    "reference_id"=>nil,
    "effective_from"=>"2021-09-01T18:30:00.000Z",
    "effective_till"=>"2021-09-04T18:30:00.000Z",
    "valid_from"=>"2021-09-07T18:30:00.000Z",
    "valid_till"=>"3000-01-01T00:00:00.000Z"
  },
  {
    "id"=>6,
    "cash_account_id"=>1,
    "amount"=>900,
    "reference_id"=>nil,
    "effective_from"=>"2021-09-04T18:30:00.000Z",
    "effective_till"=>"3000-01-01T00:00:00.000Z",
    "valid_from"=>"2021-09-07T18:30:00.000Z",
    "valid_till"=>"3000-01-01T00:00:00.000Z"
  }
]
```

From the time ranges, they understand that the balance dates were correct and not altered, but the amounts were corrected a day after the amounts were initially recorded.

They inform the customer about exactly what happened with his accounts in the last two days.

The customer, wanting to ensure that everything is right, asks them when the additional $300 was recorded. and they inform the customer that the date of the second deposit is 4 days ago, but the correct amount was updated yesterday.

The customer feels satisfied that all the changes were tracked accurately, thanks us and leaves

## Installation

Install the gem with

      gem 'time-travel'

Then run:

    bundle install

## Usage

### Creating a new model that tracks history

To create a new model which will track history, use the `time_travel` generator to create a scaffold

    bundle exec rake generate time_travel <NewModel> <fields>

Then, include `TimeTravel::TimelineHelper` in your ActiveRecord Model, and define which fields identify a unique timeline in your model for which changes and corrections need to be tracked

In the example below. a `CashBalance` model has a `:cash_account_id` field which uniquely identifies the account for which the cash balance needs to be tracked.

    class CashBalance < ActiveRecord::Base
      include TimeTravel::TimelineHelper

      def self.timeline_fields
        :cash_account_id
      end
    end

### Adding history tracking to an existing model

#### _Adding fields for history tracking_

To add history tracking to an existing model, you can use the `time_travel` generator, specifying the name of a model that already exists.

    bundle exec rake generate time_travel <ExistingModel>

#### _Migrating existing data_

To migrate existing data, you'll need to populate the effective and valid time ranges in each record in your model with a custom script of your own. An easy way to do this for a table that has a single date field is to order the records by the field and chain the dates from subsequent records to create the effective time range. The valid time range can be set to the current date onwards if you don't care about history prior to the migration.

### Manipulating data in a Time Travel model

To apply changes to a timeline, first create a timeline object

    timeline=balance.timeline(cash_account_id: 1)

Then use the `create`, `update` or `terminate` methods to modify the timeline.

In case you're not sure if you need to create a new timeline or update it, you can always call `create_or_update` to do the dirty work for you.

You can pass in `effective_from` and `effective_till` dates to indicate the period during which you want to create or update records. This is especially useful if you want to correct an older record.

The `valid_from` and `valid_till` fields are managed by the gem, based on when records are added or corrected and cannot be modified explicitly on the timeline.

Here are some examples of operations:

    # create account with balance of Rs. 500, effective from now onwards
    timeline.create({amount: 500})
    # create account with balance Rs. 500, effective from 1st of August
    timeline.create({amount: 500}, effective_from: Date.parse("01/09/2018").beginning_of_day))
    # update account with balance Rs. 1000, effective from now onwards
    timeline.update({amount: 1000})
    # update account with balance Rs. 1500, effective from 20th of August
    timeline.update({amount: 1500}, effective_from: Date.parse("20/09/2018").beginning_of_day)
    # correct account balance to Rs. 2000 between 5th and 22nd of August
    timeline.update({amount: 2000},
              effective_from: Date.parse("05/09/2018").begining_of_day,
              effective_till: Date.parse("22/09/2018").begining_of_day)
    # close account now
    timeline.terminate()
    # close account, effective from 30th August timeline.terminate(effective_from: Date.parse("30/09/2018"))

Updates can be applied in bulk by supplying attributes in an array and using the `bulk_update` method

### Accessing the timelines

To access the records in the timelines, use the `at` and `as_of` methods.

The `at` method returns a single record at a point in the timelines. 

```
# retrieve a currently valid record, effective 2 days ago
timeline.at(Time.now - 2 days)
# retrieve record which was valid and effective 2 days ago
timeline.at(Time.now - 2.days, as_of: Time.now - 2 days) 
```

The `as_of` method returns the entire history of records which were valid on a given date

```
# the currently valid set of records
timeline.as_of(Time.now)
# the set of records valid two days ago
timeline.as_of(Time.now - 2.days)
```

### Updating data directly

Data on any record can be directly updated by using ActiveRecord methods on your model. 

You might want to do this for fields which you don't want to track on the timelines.

Avoid updating the time ranges directly though, unless you really know what you're doing.

We allow updates to the time ranges since you might need to migrate an existing model to support `time_travel` functionality.

### SQL and Native modes

By default time travel applies updates using native ruby logic.

For performance, the sql mode is also available with support for Postgres.

To switch modes, create an initializer as follows

    TimeTravel.configure do
      update_mode="sql"
    end

and install the postgres plsql function with

    rake time_travel:create_postgres_function
    
## Behind the Scenes

The time travel gem uses bi-temporal modelling to track changes and corrections. There's a lot of material online that covers it in-case you want to dig deeper into what makes the gem work.

