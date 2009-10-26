$:.unshift "#{File.dirname(__FILE__)}/lib"
require 'active_record/acts/google_calendar'
ActiveRecord::Base.class_eval { include ActiveRecord::Acts::GoogleCalendar }
