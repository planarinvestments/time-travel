# Time Travel

The `time_travel` gem implements a data-modelling concept known as bitemporal data modelling, which makes it easy to record and trace historical changes to your data. Its similar to versioning tables, but its main difference is that all historical data is tracked in the same table, making it always available and easily accessible.

## Installation

To install the gem, reference this git repository in your `Gemfile`

    git "https://<your-personal-access-token>:x-oauth-basic@github.com/planarinv/elder-wand.git" do
      gem 'time_travel'
    end

Then run:

    bundle install

## Generators and its usage

Run the following generator to create sql functions used by gem to manage history

    bundle exec rails generate time_travel_sql create

### Creating a new model that tracks history

To create a new model which will track history, use the `time_travel` generator to create a scaffold

    bundle exec rake generate time_travel <NewModel> <fields>

Then, include `TimeTravel` in your ActiveRecord Model, and define which field tracks the entity to which a record belongs to

In the example below. a `CashTransaction` model has a `:cash_account_id` field which uniquely identifies the account for which transactions are tracked.

    class CashTransaction < ActiveRecord::Base
      include TimeTravel

      def self.time_travel_identifier
        :cash_account_id
      end
    end

### Adding history tracking to an existing model

#### _Adding fields for history tracking_

To add history tracking to an existing model, you can use the `time_travel` generator, specifying the name of a model that already exists.

    bundle exec rake generate time_travel <ExistingModel>

Note that this creates date fields for history tracking but does not perform the migration of existing data for history tracking. If you need to migrate existing data, you'll need to write scripts for that.

#### _Migrating existing data_

To migrate existing data, you'll need to populate the following fields in each record in your model with a custom script of your own.

- **effective_from, effective_till** - the data-range for which the data in the record is applicable. If the data in the record is currently applicable, `effective_till` should be set to the constant `INFINITE_DATE`.
- **valid_from, valid_till** - the date range for which the data in the record was thought to be accurate. For currently valid information, set `valid_till` to the constant `INFINITE_DATE`.

For example,

We came to know on the 25th of Augest, that Tom had a balance of Rs. 1000 from 1st August to 20th August. This is represented by:

**effective_from:** 1st August
**effective_to:** 20th August
**valid_from:** 25th August
**valid_till:** INFINITE_DATE

## Manipulating data in a Time Travel model

Use the `create`, `update!` and `delete` methods to manipulate data.

Note that you cannot pass in `valid_from` and `valid_till` fields because those are set by the gem, based on when records are corrected.

However, you can pass in `effective_from` and `effective_till` dates to indicate the period during which you want to create or update records.

Here are some examples of operations:

    # create account with balance of Rs. 500, effective from now onwards
    balance.create(cash_account_id: 1, amount: 500)
    # create account with balance Rs. 500, effective from 1st of August
    balance.create(cash_account_id: 1, amount: 500, effective_from: Date.parse("01/09/2018").beginning_of_day))
    # update account with balance Rs. 1000, effective from now onwards
    balance.update!(cash_account_id: 1, amount: 1000)
    # update account with balance Rs. 1500, effective from 20th of August
    balance.update!(cash_account_id: 1, amount: 1500, effective_from: Date.parse("20/09/2018").beginning_of_day)
    # correct account balance to Rs. 2000 between 5th and 22nd of August
    balance.update(cash_account_id: 1, amount: 2000,
              effective_from: Date.parse("05/09/2018").beggining_of_day,
              effective_till: Date.parse("22/09/2018").beggining_of_day)
    # close account now
    balance.delete(cash_account_id: 1)
    # close account, effective from 30th August
    balance.delete(cash_account_id: 1, effective_from: Date.parse("30/09/2018"))

## Accessing history of a record

Currently valid history can be accessed using the `history` method for a given entity like a cash account.

To access all of the history including corrections, pass `true` as the second argument to the method.

Examples follow:

    balance.history(1) # cash_account_id: 1
    balance.history(1, true) # cash_account_id: 1 with corrections

## Rake task

The following rake task has to be invoked before deployment and test case setup, as to create the sql functions
used by the gem to manage history

    rake time_travel:create_postgres_function
