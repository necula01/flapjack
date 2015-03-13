#!/usr/bin/env ruby

require 'sinatra/base'

require 'flapjack/data/contact'
require 'flapjack/data/rule'

module Flapjack
  module Gateways
    class JSONAPI < Sinatra::Base
      module Methods
        module MediumLinks

          def self.registered(app)
            app.helpers Flapjack::Gateways::JSONAPI::Helpers::Headers
            app.helpers Flapjack::Gateways::JSONAPI::Helpers::Miscellaneous
            app.helpers Flapjack::Gateways::JSONAPI::Helpers::ResourceLinks

            app.class_eval do
              swagger_args = ['media',
                              Flapjack::Data::Medium,
                              {'contact' => Flapjack::Data::Contact,
                               'rules'   => Flapjack::Data::Rule}]

              swagger_multi_args = ['media',
                              Flapjack::Data::Medium,
                              {'rules'   => Flapjack::Data::Rule}]

              swagger_post_links(*swagger_multi_args)
              swagger_get_links(*swagger_args)
              swagger_patch_links(*swagger_args)
              swagger_delete_links(*swagger_multi_args)
            end

            app.post %r{^/media/(#{Flapjack::UUID_RE})/links/(rules)$} do
              medium_id  = params[:captures][0]
              assoc_type = params[:captures][1]

              resource_post_links(Flapjack::Data::Medium, 'media', medium_id, assoc_type)
              status 204
            end

            app.get %r{^/media/(#{Flapjack::UUID_RE})/(?:links/)?(contact|rules)} do
              medium_id = params[:captures][0]
              assoc_type = params[:captures][1]

              status 200
              resource_get_links(Flapjack::Data::Medium, 'media', medium_id, assoc_type)
            end

            app.patch %r{^/media/(#{Flapjack::UUID_RE})/links/(contact|rules)$} do
              medium_id = params[:captures][0]
              assoc_type = params[:captures][1]

              resource_patch_links(Flapjack::Data::Medium, 'media', medium_id, assoc_type)
              status 204
            end

            app.delete %r{^/media/(#{Flapjack::UUID_RE})/links/(rules)$} do
              medium_id = params[:captures][0]
              assoc_type = params[:captures][1]

              resource_delete_links(Flapjack::Data::Medium, 'media', medium_id,
                                    assoc_type)
              status 204
            end

          end
        end
      end
    end
  end
end