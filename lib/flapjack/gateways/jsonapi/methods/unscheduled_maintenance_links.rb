#!/usr/bin/env ruby

require 'sinatra/base'

module Flapjack
  module Gateways
    class JSONAPI < Sinatra::Base
      module Methods
        module UnscheduledMaintenanceLinks

          def self.registered(app)
            app.helpers Flapjack::Gateways::JSONAPI::Helpers::Headers
            app.helpers Flapjack::Gateways::JSONAPI::Helpers::Miscellaneous
            app.helpers Flapjack::Gateways::JSONAPI::Helpers::ResourceLinks

            app.class_eval do
              swagger_args = ['unscheduled_maintenances',
                              Flapjack::Data::UnscheduledMaintenance,
                              {'check' => Flapjack::Data::Check}]

              swagger_get_links(*swagger_args)
              swagger_patch_links(*swagger_args)
            end

            app.get %r{^/unscheduled_maintenances/(#{Flapjack::UUID_RE})/(?:links/)?(check)} do
              unscheduled_maintenance_id = params[:captures][0]
              assoc_type                 = params[:captures][1]

              status 200
              resource_get_links(Flapjack::Data::UnscheduledMaintenance,
                'unscheduled_maintenances', unscheduled_maintenance_id, assoc_type)
            end

            app.patch %r{^/unscheduled_maintenances/(#{Flapjack::UUID_RE})/links/(check)$} do
              unscheduled_maintenance_id = params[:captures][0]
              assoc_type                 = params[:captures][1]

              resource_patch_links(Flapjack::Data::UnscheduledMaintenance,
                'unscheduled_maintenances', unscheduled_maintenance_id, assoc_type)
              status 204
            end

          end
        end
      end
    end
  end
end