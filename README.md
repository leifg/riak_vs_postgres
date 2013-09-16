# Riak vs Postgres Benchmark

Just to play around with the performance

## Prequisites

You need to have [Riak](http://basho.com/riak/) and [Postgres](http://www.postgresql.org/) installed.

For postgres you need to have a database created with name 'entities'

    createdb -O <user> -E utf8 entities

## Running

To run the benchmark, simply type:

    bundle exec ruby run_benchmark.rb