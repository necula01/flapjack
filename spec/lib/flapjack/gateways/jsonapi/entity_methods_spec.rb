require 'spec_helper'
require 'flapjack/gateways/jsonapi'

describe 'Flapjack::Gateways::JSONAPI::EntityMethods', :sinatra => true, :logger => true do

  def app
    Flapjack::Gateways::JSONAPI
  end

  let(:entity)          { double(Flapjack::Data::Entity) }
  let(:entity_check)    { double(Flapjack::Data::EntityCheck) }

  let(:entity_name)     { 'www.example.net'}
  let(:entity_name_esc) { URI.escape(entity_name) }
  let(:check)           { 'ping' }

  let(:entity_presenter)       { double(Flapjack::Gateways::JSONAPI::EntityPresenter) }
  let(:entity_check_presenter) { double(Flapjack::Gateways::JSONAPI::EntityCheckPresenter) }

  let(:redis)           { double(::Redis) }

  before(:all) do
    Flapjack::Gateways::JSONAPI.class_eval {
      set :raise_errors, true
    }
  end

  before(:each) do
    expect(Flapjack::RedisPool).to receive(:new).and_return(redis)
    Flapjack::Gateways::JSONAPI.instance_variable_set('@config', {})
    Flapjack::Gateways::JSONAPI.instance_variable_set('@logger', @logger)
    Flapjack::Gateways::JSONAPI.start
  end

  after(:each) do
    # if last_response.status >= 200 && last_response.status < 300
    #   expect(last_response.headers.keys).to include('Access-Control-Allow-Methods')
    #   expect(last_response.headers['Access-Control-Allow-Origin']).to eq("*")
    #   unless last_response.status == 204
    #     expect(Oj.load(last_response.body)).to be_a(Enumerable)
    #     expect(last_response.headers['Content-Type']).to eq(Flapjack::Gateways::JSONAPI::JSONAPI_MEDIA_TYPE)
    #   end
    # end
  end

  it "creates an acknowledgement for an entity check" do
    expect(Flapjack::Data::Entity).to receive(:find_by_name).
      with(entity_name, :redis => redis).and_return(entity)
    expect(Flapjack::Data::EntityCheck).to receive(:for_entity).
      with(entity, check, :redis => redis).and_return(entity_check)

    expect(entity_check).to receive(:entity_name).and_return(entity_name)
    expect(entity_check).to receive(:check).and_return(check)

    expect(Flapjack::Data::Event).to receive(:create_acknowledgement).
      with(entity_name, check, :summary => nil, :duration => (4 * 60 * 60), :redis => redis)

    apost '/acknowledgements',:check => {entity_name => check}
    expect(last_response.status).to eq(204)
  end

  it "deletes an unscheduled maintenance period for an entity check" do
    end_time = Time.now + (60 * 60) # an hour from now
    expect(entity_check).to receive(:end_unscheduled_maintenance).with(end_time.to_i)

    expect(Flapjack::Data::EntityCheck).to receive(:for_entity).
      with(entity, check, :redis => redis).and_return(entity_check)

    expect(Flapjack::Data::Entity).to receive(:find_by_name).
      with(entity_name, :redis => redis).and_return(entity)

    adelete "/unscheduled_maintenances", :check => {entity_name => check}, :end_time => end_time.iso8601
    expect(last_response.status).to eq(204)
  end

  it "creates a scheduled maintenance period for an entity check" do
    start = Time.now + (60 * 60) # an hour from now
    duration = (2 * 60 * 60)     # two hours
    expect(Flapjack::Data::Entity).to receive(:find_by_name).
      with(entity_name, :redis => redis).and_return(entity)
    expect(Flapjack::Data::EntityCheck).to receive(:for_entity).
      with(entity, check, :redis => redis).and_return(entity_check)
    expect(entity_check).to receive(:create_scheduled_maintenance).
      with(start.getutc.to_i, duration, :summary => 'test')

    apost "/scheduled_maintenances/#{entity_name_esc}/#{check}?" +
       "start_time=#{CGI.escape(start.iso8601)}&summary=test&duration=#{duration}"
    expect(last_response.status).to eq(204)
  end

  it "doesn't create a scheduled maintenance period if the start time isn't passed" do
    duration = (2 * 60 * 60)     # two hours

    apost "/scheduled_maintenances/#{entity_name_esc}/#{check}?" +
       "summary=test&duration=#{duration}"
    expect(last_response.status).to eq(403)
  end

  it "deletes a scheduled maintenance period for an entity check" do
    start_time = Time.now + (60 * 60) # an hour from now
    expect(entity_check).to receive(:end_scheduled_maintenance).with(start_time.to_i)

    expect(Flapjack::Data::EntityCheck).to receive(:for_entity).
      with(entity, check, :redis => redis).and_return(entity_check)

    expect(Flapjack::Data::Entity).to receive(:find_by_name).
      with(entity_name, :redis => redis).and_return(entity)

    adelete "/scheduled_maintenances", :check => {entity_name => check}, :start_time => start_time.iso8601
    expect(last_response.status).to eq(204)
  end

  it "doesn't delete a scheduled maintenance period if the start time isn't passed" do
    expect(entity_check).not_to receive(:end_scheduled_maintenance)

    adelete "/scheduled_maintenances", :check => {entity_name => check}
    expect(last_response.status).to eq(403)
  end

  it "deletes scheduled maintenance periods for multiple entity checks" do
    start_time = Time.now + (60 * 60) # an hour from now

    entity_check_2 = double(Flapjack::Data::EntityCheck)

    expect(entity_check).to receive(:end_scheduled_maintenance).with(start_time.to_i)
    expect(entity_check_2).to receive(:end_scheduled_maintenance).with(start_time.to_i)

    expect(Flapjack::Data::EntityCheck).to receive(:for_entity).
      with(entity, check, :redis => redis).and_return(entity_check)
    expect(Flapjack::Data::EntityCheck).to receive(:for_entity).
      with(entity, 'foo', :redis => redis).and_return(entity_check_2)

    expect(Flapjack::Data::Entity).to receive(:find_by_name).
      with(entity_name, :redis => redis).and_return(entity)

    adelete "/scheduled_maintenances", :check => {entity_name => [check, 'foo']}, :start_time => start_time.iso8601
    expect(last_response.status).to eq(204)
  end

  it "creates test notification events for all checks on an entity" do
    expect(entity).to receive(:check_list).and_return([check, 'foo'])
    expect(entity).to receive(:name).twice.and_return(entity_name)
    expect(Flapjack::Data::Entity).to receive(:find_by_name).
      with(entity_name, :redis => redis).and_return(entity)

    expect(entity_check).to receive(:entity).and_return(entity)
    expect(entity_check).to receive(:entity_name).and_return(entity_name)
    expect(entity_check).to receive(:check).and_return(check)

    expect(Flapjack::Data::EntityCheck).to receive(:for_entity).
      with(entity, check, :redis => redis).and_return(entity_check)

    entity_check_2 = double(Flapjack::Data::EntityCheck)
    expect(entity_check_2).to receive(:entity).and_return(entity)
    expect(entity_check_2).to receive(:entity_name).and_return(entity_name)
    expect(entity_check_2).to receive(:check).and_return('foo')

    expect(Flapjack::Data::EntityCheck).to receive(:for_entity).
      with(entity, 'foo', :redis => redis).and_return(entity_check_2)

    expect(Flapjack::Data::Event).to receive(:test_notifications).
      with(entity_name, check, hash_including(:redis => redis))

    expect(Flapjack::Data::Event).to receive(:test_notifications).
      with(entity_name, 'foo', hash_including(:redis => redis))

    apost '/test_notifications', :entity => entity_name
    expect(last_response.status).to eq(204)
  end

  it "creates a test notification event for check on an entity" do
    expect(Flapjack::Data::Entity).to receive(:find_by_name).
      with(entity_name, :redis => redis).and_return(entity)
    expect(entity).to receive(:name).and_return(entity_name)
    expect(entity_check).to receive(:entity).and_return(entity)
    expect(entity_check).to receive(:entity_name).and_return(entity_name)
    expect(entity_check).to receive(:check).and_return(check)
    expect(Flapjack::Data::EntityCheck).to receive(:for_entity).
      with(entity, check, :redis => redis).and_return(entity_check)

    expect(Flapjack::Data::Event).to receive(:test_notifications).
      with(entity_name, check, hash_including(:redis => redis))

    apost '/test_notifications', :check => {entity_name => check}
    expect(last_response.status).to eq(204)
  end

  it "retrieves all entities" do
    entity_core = {'id'         => '1234',
                   'name' => 'www.example.com'
                  }
    expect(entity).to receive(:id).twice.and_return('1234')

    expect(Flapjack::Data::Entity).to receive(:contacts_jsonapi).
      with(['1234'], :redis => redis).and_return([[], {}])
    expect(entity).to receive(:linked_contact_ids=).with(nil)
    expect(entity).to receive(:to_jsonapi).and_return(entity_core.to_json)
    expect(Flapjack::Data::Entity).to receive(:all).with(:redis => redis).
      and_return([entity])

    aget '/entities'
    expect(last_response).to be_ok
    expect(last_response.body).to eq({:entities => [entity_core], :linked => {'contacts' => []}}.to_json)
  end

  it "retrieves one entity"

  it "retrieves a group of entities"

  it "creates entities from a submitted list" do
    entities = {'entities' =>
      [
       {"id" => "10001",
        "name" => "clientx-app-01",
        "contacts" => ["0362","0363","0364"]
       },
       {"id" => "10002",
        "name" => "clientx-app-02",
        "contacts" => ["0362"]
       }
      ]
    }
    expect(Flapjack::Data::Entity).to receive(:add).twice

    apost "/entities", entities.to_json, {'CONTENT_TYPE' => Flapjack::Gateways::JSONAPI::JSONAPI_MEDIA_TYPE}
    expect(last_response.status).to eq(200)
    expect(last_response.body).to eq('["10001","10002"]')
  end

  it "does not create entities if the data is improperly formatted" do
    expect(Flapjack::Data::Entity).not_to receive(:add)

    apost "/entities", {'entities' => ["Hello", "there"]}.to_json,
      {'CONTENT_TYPE' => Flapjack::Gateways::JSONAPI::JSONAPI_MEDIA_TYPE}
    expect(last_response.status).to eq(403)
  end

  it "does not create entities if they don't contain an id" do
    entities = {'entities' =>
      [
       {"id" => "10001",
        "name" => "clientx-app-01",
        "contacts" => ["0362","0363","0364"]
       },
       {"name" => "clientx-app-02",
        "contacts" => ["0362"]
       }
      ]
    }
    expect(Flapjack::Data::Entity).to receive(:add)

    apost "/entities", entities.to_json, {'CONTENT_TYPE' => Flapjack::Gateways::JSONAPI::JSONAPI_MEDIA_TYPE}
    expect(last_response.status).to eq(403)
  end

end
