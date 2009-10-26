module ActiveRecord
  module Acts #:nodoc:
    module List #:nodoc:
      def self.included(base)
        base.extend(ClassMethods)
      end
      
      # This +acts_as+ extension provides the capabilities for updating a Google Calendar whenever the model is updated.
      # The class that has this specified needs to have a +google_calendar_remote_id+ column defined as a string on
      # the mapped database table.
      
      # Event example:
      #   class Event < ActiveRecord::Base
      #     acts_as_google_calendar
      #     validates_presence_of :title, :starts_at, :ends_at
      #   end
      #
      #   # Create an event in the google calendar
      #   event = Event.create! :title => "My cool event", :starts_at => Time.zone.now, :ends_at => 1.hour.from_now
      #
      #   # Update the event in the calendar
      #   event.title = "My best event"
      #   event.save
      #
      #   # Destroy the event in the calendar
      #   event.destroy
      
      module ClassMethods
        # Configuration options are:
        #
        # * +column+ - specifies the column name to use for keeping the edit_url of the Google Calendar
        #   defaults to :google_calendar_remote_id
        #
        # * +calendar+ - the title of the calendar you want to update
        #   default to :default (the default calendar for your Google Apps account)
        #
        # # NOT SUPPORTED YET:
        # #* +config+ - a hash of the login credentials you want to use
        # #  defaults to the environment-specific credentials GoogleApps reads from config/google_apps.yml
        def acts_as_google_calendar(options = {})
          configuration = { :calendar => :default, :column => :google_calendar_remote_id }
          configuration.update(options) if options.is_a?(Hash)
          class_eval <<-EOV
            include ActiveRecord::Acts::List::InstanceMethods
            
            def google_calendar_remote_id_column
              '#{configuration[:column].to_s}'
            end
            
            after_create :google_calendar_after_create
            after_update :google_calendar_after_update
            after_destroy :google_calendar_after_destroy
          EOV
        end
        
        # All the methods available to a record that has had <tt>acts_as_google_calendar</tt> specified. 
        module InstanceMethods
          # override this method to pass different values to the calendar
          def google_calendar_mapping
            { :title => send(title), :starts_at => send(:starts_at), :ends_at => send(:ends_at)}
          end
          
          def google_calendar_after_create
            create_google_calendar_event if google_calendar_create_conditions
          end

          def google_calendar_after_update
            if google_calendar_update_conditions
              if self.send(google_calendar_remote_id_column).blank?
                create_google_calendar_event
              else
                update_google_calendar_event
              end
            else
              destroy_google_calendar_event if google_calendar_destroy_conditions
            end
          end

          def google_calendar_after_destroy
            destroy_google_calendar_event
          end
          
          def google_calendar_create_conditions
            Rails.env != 'test'
          end

          def google_calendar_update_conditions
            Rails.env != 'test'
          end

          def google_calendar_destroy_conditions
            Rails.env != 'test' && !self.send(google_calendar_remote_id_column).blank?
          end
          
          def google_calendar
            if configuration[:calendar] == :default
              GoogleApps::CalendarsConnection.new.calendars.first
            else
              GoogleApps::CalendarsConnection.new.calendars.detect{|c| c.title == configuration[:calendar]}
            end
          end

          def create_google_calendar_event
            calendar_event = google_calendar.create_event! :title => google_docs_title,
              :description => google_docs_description,
              :location => google_docs_location,
              :starts_at => starts_at,
              :ends_at => ends_at

            self.update_attribute self.send(google_calendar_remote_id_column), calendar_event.edit_url
          end

          def update_google_calendar_event
            GoogleCalendarEvent.new(:edit_url => self.send(google_calendar_remote_id_column)).update! *google_calendar_mapping
          end

          def destroy_google_calendar_event
            GoogleCalendarEvent.new(:edit_url => self.send(google_calendar_remote_id_column)).destroy if google_calendar_destroy_condition
          end
        end
      end
    end
  end
end