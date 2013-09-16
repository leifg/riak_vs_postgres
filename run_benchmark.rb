require 'riak'
require 'pg'
require 'benchmark'

SEED = 11021985
RANDOM_RANGE = [('a'..'z'), ('A'..'Z')].map{ |i| i.to_a }.flatten
FILENAME = ENV['statistic.csv'] || 'riak_vs_postgres.csv'

File.open(FILENAME,'w'){|f| f.write("db_type,size,user,system,total,real\n")}

def generate_random_string(kbytes)
  string_random = Random.new
  random_string = ''
  (kbytes * 1024).times do
    random_string << RANDOM_RANGE[string_random.rand(RANDOM_RANGE.size)]
  end
  random_string
end

runs = 100
writes = (runs * 0.9).to_i

Riak.disable_list_keys_warnings = true
client = Riak::Client.new(:protocol => 'pbc')
bucket = client.bucket('entities')
conn = PG.connect( dbname: 'entities' )

(1..10).each do |multi|
  kbytes = 100 * multi

  data_to_write = generate_random_string(kbytes)

  conn.exec('drop table if exists documents')
  conn.exec('create table documents (id integer, value text)')
  conn.exec('create unique index on documents (id)')

  Benchmark.bm do |x|
    pg_res = x.report("Postgres #{kbytes} KB") do
      r = Random.new(SEED)
      runs.times do
        id = r.rand(writes)
        if conn.exec("select id from documents where id = #{id}").count > 0
          conn.exec("update documents set value = '#{data_to_write}' where id = #{id}")
        else
          conn.exec("insert into documents values (#{id}, '#{data_to_write}')")
        end
      end
    end
    File.open(FILENAME,'a'){|f| f.write("postgres,#{kbytes * 1024},#{pg_res.utime},#{pg_res.stime},#{pg_res.total},#{pg_res.real}\n")}

    r = Random.new(SEED)
    riak_res = x.report("Riak     #{kbytes} KB") do
      runs.times do
        id = "listing_#{r.rand(writes)}"
        object = Riak::RObject.new(bucket, id)
        object.content_type = 'application/json'
        object.data = data_to_write
        object.store
      end
    end
    File.open(FILENAME,'a'){|f| f.write("riak,#{kbytes * 1024},#{riak_res.utime},#{riak_res.stime},#{riak_res.total},#{riak_res.real}\n")}
  end
end
