require 'core_ext/module/include'
require 'pusher'

module Travis
  module Notifications
    module Handler

      # Notifies registered clients about various state changes through Pusher.
      class Pusher
        EVENTS = [/build:(started|finished)/, /job:test:(created|started|log|finished)/, /worker:.*/]

        include Logging

        include do
          def notify(event, object, *args)
            push(event, object, *args)
          end

          protected

            def push(event, object, *args)
              data  = args.last.is_a?(Hash) ? args.pop : {}
              data  = payload_for(event, object, data)
              event = client_event_for(event)

              channels_for(event, object).each do |channel|
                trigger(channel, event, data)
              end
            end

            def client_event_for(event)
              case event
              when /job:.*/
                event.gsub(/(test|configure):/, '')
              else
                event
              end
            end

            def channels_for(event, object)
              case event
              when 'job:log'
                ["job-#{object.id}"]
              else
                ['common']
              end
            end

            def trigger(channel, event, data)
              Travis.pusher[channel].trigger(event, data)
            end

            def payload_for(event, object, extra = {})
              renderer_for(event, object).new(object).data(extra)
            end

            def renderer_for(event, object)
              object_type = object.class.name.split('::').first
              case object_type
              when 'Worker'
                Api::Pusher::Worker
              else
                event_type  = event.split(':').last.camelize
                Api::Pusher.const_get(object_type).const_get(event_type)
              end
            end
        end
      end
    end
  end
end
