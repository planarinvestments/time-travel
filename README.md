# Time Travel

The `time_travel` gem implements a data-modelling concept known as bitemporal data modelling, which makes it easy to record and trace historical changes and corrections to your data. Its similar to versioning tables, but its main difference is that all historical data is tracked in the same table, making it always available and easily accessible.

## Installation

To install the gem, reference this git repository in your `Gemfile`

    git "https://<your-personal-access-token>:x-oauth-basic@github.com/planarinv/elder-wand.git" do
      gem 'time_travel'
    end

Then run:

    bundle install

## How it works

In Bitemporal data modelling, every record is represented by two time ranges

- **effective_from, effective_till** - the time range for which the data in the record is applicable. If the data in the record is currently applicable, `effective_till` should be set to the constant `INFINITE_DATE`.
- **valid_from, valid_till** - the time range for which the data in the record was thought to be accurate. For currently valid information, set `valid_till` to the constant `INFINITE_DATE`.

While the effective time range tracks updates on the timeline, the valid time range tracks corrections.

Lets see how this works with an example.

One day, John, a carpenter, opens a bank account with a cash balance of $100 on Jan 1, 2020, and the bank formally opened the account on the 3rd.

This is represented by

    Record 1
    --------
    owner: "John"
    amount: 100
    effective_from: Jan 01, 2020
    effective_till: infinity
    valid_from: Jan 03, 2020
    valid_till: infinity

So while the account is opened as of Jan 1, 2020(`effective_from`), the bank formally recorded this information on 3rd(`valid_from`), and so as far as the bank is concerned, it knows that John's account existed from 1st only from the 3rd of Jan!

If John ever walked up to the bank and claimed that he deposited addtional money on the 2nd, the bank would be quick to point out that they had not formally opened the account till the 3rd of Jan.

Now lets try an update to the account, lets say John deposited $200 on Feb 1st, which the bank recorded on 2nd of Feb, the resulting records would look like this
 
    Record 1
    --------
    owner: "John"
    amount: 100
    effective_from: Jan 01, 2020
    effective_till: infinity
    valid_from: Jan 03, 2020
    valid_till: Feb 02, 2020
    
    Record 2
    --------
    owner: "John"
    amount: 100
    effective_from: Jan 01, 2020
    effective_till: Feb 01, 2020
    valid_from: Feb 02, 2020
    valid_till: infinity
    
    Record 3
    --------
    owner: "John"
    amount: 300
    effective_from: Feb 01, 2020
    effective_till: infinity
    valid_from: Feb 02, 2020
    valid_till: infinity

Record 1 (Our older record when John opened his account) doesn't hold good anymore since John's balance of 100 is applicable only till the 1st of Feb.
Record 2 is the corrected Record 1 where the effective time range is set from 1st Jan, 2020 to 1st Feb 2020.
Record 3 reflects the updated balance from Feb 1st onwards.

Finally lets add a correction to see what goes on with the records.

On Feb 5th, a Bank employee notices that John had actually deposited $250 and not $200 on Feb 1. Here's what happens to the records

    Record 1
    --------
    owner: "John"
    amount: 100
    effective_from: Jan 01, 2020
    effective_till: infinity
    valid_from: Jan 03, 2020
    valid_till: Feb 02, 2020
    
    Record 2
    --------
    owner: "John"
    amount: 100
    effective_from: Jan 01, 2020
    effective_till: Feb 01, 2020
    valid_from: Feb 02, 2020
    valid_till: infinity
    
    Record 3
    --------
    owner: "John"
    amount: 300
    effective_from: Feb 01, 2020
    effective_till: infinity
    valid_from: Feb 02, 2020
    valid_till: Feb 05, 2020
    
    Record 4
    --------
    owner: "John"
    amount: 350
    effective_from: Feb 01, 2020
    effective_till: infinity
    valid_from: Feb 05, 2020
    valid_till: infinity


Record 1 and Record 2 are unaffected because the changes were not applied on the applicable date range of those records.
Record 3 is now marked as valid only until Feb 5th
Record 4 is the corrected record which contains the new balance applicable from Feb 1st onwards, but valid only from Feb 5th onwards.

So lets say John walks in now, after seeing some of these changes reflecting on his account, he asks:

I don't know why but my balance suddenly went up by $50, can you explain why?

To which the bank promptly responds that

1. On Feb 2nd, we erroneously recorded your balance as $300, assuming a deposit of $200 for Feb 1st
2. On Feb 5th, we noticed that you had deposited $250 and not $200, and corrected it

All of this data can be pulled out by simply taking a look at the records and analyzing the effective and valid date ranges, making bitemporal updates a very robust mechanism to track changes and corrections.

## How to Use it

### Generators and its usage

Run the following generator to create sql functions used by gem to manage history

    bundle exec rails generate time_travel_sql create

### Creating a new model that tracks history

To create a new model which will track history, use the `time_travel` generator to create a scaffold

    bundle exec rake generate time_travel <NewModel> <fields>

Then, include `TimeTravel::TimelineHelper` in your ActiveRecord Model, and define which fields identify a unique timeline in your model for which changes and corrections need to be tracked

In the example below. a `CashBalance` model has a `:cash_account_id` field which uniquely identifies the account for which the cash balance needs to be tracked.

    class CashTransaction < ActiveRecord::Base
      include TimeTravel::TimelineHelper

      def self.timeline_fields
        :cash_account_id
      end
    end

#### Adding history tracking to an existing model

##### _Adding fields for history tracking_

To add history tracking to an existing model, you can use the `time_travel` generator, specifying the name of a model that already exists.

    bundle exec rake generate time_travel <ExistingModel>

Note that this creates date fields for history tracking but does not perform the migration of existing data for history tracking. If you need to migrate existing data, you'll need to write scripts for that.

##### _Migrating existing data_

To migrate existing data, you'll need to populate the following fields in each record in your model with a custom script of your own.

- **effective_from, effective_till** - the date range for which the data in the record is applicable. If the data in the record is currently applicable, `effective_till` should be set to the constant `INFINITE_DATE`.
- **valid_from, valid_till** - the date range for which the data in the record was thought to be accurate. For currently valid information, set `valid_till` to the constant `INFINITE_DATE`.

For example,

We came to know on the 25th of Augest, that Tom had a balance of Rs. 1000 from 1st August to 20th August. This is represented by:

**effective_from:** 1st August
**effective_to:** 20th August
**valid_from:** 25th August
**valid_till:** INFINITE_DATE

### Manipulating data in a Time Travel model

To apply changes to a timeline, first create a timeline object

    timeline=balance.timeline(cash_account_id: 1)

Then use the `create`, `update` or `terminate` methods to modify the timeline

Note that you cannot pass in `valid_from` and `valid_till` fields because those are set by the gem, based on when records are corrected.

However, you can pass in `effective_from` and `effective_till` dates to indicate the period during which you want to create or update records.

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
              effective_from: Date.parse("05/09/2018").beggining_of_day,
              effective_till: Date.parse("22/09/2018").beggining_of_day)
    # close account now
    timeline.terminate()
    # close account, effective from 30th August
    timeline.terminate(effective_from: Date.parse("30/09/2018"))

Updates can be applied in bulk by supplying attributes in an array and using the `bulk_update` method

### Accessing history of a record

Currently valid history can be accessed using the `effective_history` method of the timeline object

To access all of the history including corrections, call the `history` method of the timeline object

Examples follow:

    timeline.effective_history
    timeline.full_history # cash_account_id: 1 with corrections

### SQL and Native modes

By default time_travel applies updates using native ruby logic.

For performance, the sql mode is also available with support for Postgres.

To switch modes, create an initializer as follows

    TimeTravel.configure do
      update_mode="sql"
    end

and install the postgres plsql function with

    rake time_travel:create_postgres_function
