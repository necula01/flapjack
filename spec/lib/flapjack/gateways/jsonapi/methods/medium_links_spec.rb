require 'spec_helper'
require 'flapjack/gateways/jsonapi'

describe 'Flapjack::Gateways::JSONAPI::Methods::MediumLinks', :sinatra => true, :logger => true, :pact_fixture => true do

  include_context "jsonapi"

  let(:medium)  { double(Flapjack::Data::Medium, :id => email_data[:id]) }
  let(:contact) { double(Flapjack::Data::Contact, :id => contact_data[:id]) }
  let(:rule)    { double(Flapjack::Data::Rule, :id => rule_data[:id]) }

  let(:medium_rules)  { double('medium_rules') }

  it 'shows the contact for a medium' do
    expect(medium).to receive(:contact).and_return(contact)

    expect(Flapjack::Data::Medium).to receive(:find_by_id!).with(medium.id).
      and_return(medium)

    get "/media/#{medium.id}/contact"
    expect(last_response.status).to eq(200)
    expect(last_response.body).to be_json_eql(Flapjack.dump_json(
      :data  => {:type => 'contact', :id => contact.id},
      :links => {
        :self    => "http://example.org/media/#{medium.id}/links/contact",
        :related => "http://example.org/media/#{medium.id}/contact",
      }
    ))
  end

  it 'changes the contact for a medium' do
    expect(Flapjack::Data::Medium).to receive(:lock).
      with(Flapjack::Data::Contact).and_yield

    expect(Flapjack::Data::Medium).to receive(:find_by_id!).with(medium.id).
      and_return(medium)
    expect(Flapjack::Data::Contact).to receive(:find_by_id!).with(contact.id).
      and_return(contact)

    expect(medium).to receive(:contact=).with(contact)

    patch "/media/#{medium.id}/links/contact", Flapjack.dump_json(
      :data => {
        :type => 'contact',
        :id   => contact.id,
      }
    ), jsonapi_env
    expect(last_response.status).to eq(204)
  end

  it 'clears the contact for a medium' do
    expect(Flapjack::Data::Medium).to receive(:lock).
      with(Flapjack::Data::Contact).and_yield

    expect(Flapjack::Data::Medium).to receive(:find_by_id!).with(medium.id).
      and_return(medium)

    expect(medium).to receive(:contact=).with(nil)

    patch "/media/#{medium.id}/links/contact", Flapjack.dump_json(
      :data => {
        :type => 'contact',
        :id   => nil,
      }
    ), jsonapi_env
    expect(last_response.status).to eq(204)
  end

  it 'adds a rule to a medium' do
    expect(Flapjack::Data::Medium).to receive(:lock).
      with(Flapjack::Data::Rule).and_yield

    expect(Flapjack::Data::Medium).to receive(:find_by_id!).with(medium.id).
      and_return(medium)
    expect(Flapjack::Data::Rule).to receive(:find_by_ids!).with(rule.id).
      and_return([rule])

    expect(medium_rules).to receive(:add).with(rule)
    expect(medium).to receive(:rules).and_return(medium_rules)

    post "/media/#{medium.id}/links/rules", Flapjack.dump_json(
      :data => [{:type => 'rule', :id => rule.id}]), jsonapi_env
    expect(last_response.status).to eq(204)
  end

  it 'lists rules for a medium' do
    expect(medium_rules).to receive(:ids).and_return([rule.id])
    expect(medium).to receive(:rules).and_return(medium_rules)

    expect(Flapjack::Data::Medium).to receive(:find_by_id!).with(medium.id).
      and_return(medium)

    get "/media/#{medium.id}/rules"
    expect(last_response.status).to eq(200)
    expect(last_response.body).to be_json_eql(Flapjack.dump_json(
      :data  => [{:type => 'rule', :id => rule.id}],
      :links => {
        :self    => "http://example.org/media/#{medium.id}/links/rules",
        :related => "http://example.org/media/#{medium.id}/rules",
      }
    ))
  end

  it 'updates rules for a medium' do
    expect(Flapjack::Data::Medium).to receive(:lock).
      with(Flapjack::Data::Rule).and_yield

    expect(Flapjack::Data::Medium).to receive(:find_by_id!).with(medium.id).
      and_return(medium)
    expect(Flapjack::Data::Rule).to receive(:find_by_ids!).with(rule.id).
      and_return([rule])

    expect(medium_rules).to receive(:ids).and_return([])
    expect(medium_rules).to receive(:add).with(rule)
    expect(medium).to receive(:rules).twice.and_return(medium_rules)

    patch "/media/#{medium.id}/links/rules", Flapjack.dump_json(
      :data => [
        {:type => 'rule', :id => rule.id}
      ]
    ), jsonapi_env
    expect(last_response.status).to eq(204)
  end

  it 'clears rules for a medium' do
    expect(Flapjack::Data::Medium).to receive(:lock).
      with(Flapjack::Data::Rule).and_yield

    expect(Flapjack::Data::Medium).to receive(:find_by_id!).with(medium.id).
      and_return(medium)
    expect(Flapjack::Data::Rule).to receive(:find_by_ids!).with(rule.id).
      and_return([rule])

    expect(medium_rules).to receive(:ids).and_return([rule.id])
    expect(medium_rules).to receive(:delete).with(rule)
    expect(medium).to receive(:rules).twice.and_return(medium_rules)

    patch "/media/#{medium.id}/links/rules", Flapjack.dump_json(
      :data => []
    ), jsonapi_env
    expect(last_response.status).to eq(204)
  end

  it 'deletes a rule from a medium' do
    expect(Flapjack::Data::Medium).to receive(:find_by_id!).with(medium.id).
      and_return(medium)

    expect(medium_rules).to receive(:find_by_ids!).with(rule.id).
      and_return([rule])
    expect(medium_rules).to receive(:delete).with(rule)
    expect(medium).to receive(:rules).and_return(medium_rules)

    delete "/media/#{medium.id}/links/rules", Flapjack.dump_json(
      :data => [{:type => 'rule', :id => rule.id}]
    ), jsonapi_env
    expect(last_response.status).to eq(204)
  end

end
