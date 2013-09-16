require 'riak'
require 'pg'
require 'benchmark'

SEED = 11021985
FILENAME = ENV['STATISTIC_OUTPUT'] || 'riak_vs_postgres.csv'
UP_TO = 1000
STEP_SIZE = 10
runs = 100
RUN_RATIO = 0.9
writes = (runs * RUN_RATIO).to_i
RANDOM_RANGE = [('a'..'z'), ('A'..'Z')].map{ |i| i.to_a }.flatten

File.open(FILENAME,'w'){|f| f.write("db_type,size,user,system,total,real\n")}

def generate_random_string(kbytes)
  string_random = Random.new
  random_string = ''
  (kbytes * 1024).times do
    random_string << RANDOM_RANGE[string_random.rand(RANDOM_RANGE.size)]
  end
  random_string
end

Riak.disable_list_keys_warnings = true
client = Riak::Client.new(:protocol => 'pbc')
bucket = client.bucket('entities')
conn = PG.connect( dbname: 'entities' )

(1..UP_TO).select{|n| n % STEP_SIZE == 0}.each do |kbytes|
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
  end
end

(1..UP_TO).select{|n| n % STEP_SIZE == 0}.each do |kbytes|
  data_to_write = generate_random_string(kbytes)
  bucket.keys.map{|k| bucket.delete(k)}

  r = Random.new(SEED)
  Benchmark.bm do |x|
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
