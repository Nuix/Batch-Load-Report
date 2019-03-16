class TimeSpanFormatter
	def self.seconds_to_elapsed(seconds)
			second = 1
			minute = second * 60
			hour = minute * 60
			day = 24 * hour

			days = seconds / day
			seconds -= days * day
			
			hours = seconds / hour
			seconds -= hours * hour
			
			minutes = seconds / minute
			seconds -= minutes * minute

			hours = hours.to_s.rjust(2,"0")
			minutes = minutes.to_s.rjust(2,"0")
			seconds = seconds.to_s.rjust(2,"0")
			
			if days > 0
				return "#{days} Day#{days > 1 ? "s" : ""} #{hours}:#{minutes}:#{seconds}"
			else
				return "#{hours}:#{minutes}:#{seconds}"
			end
	end
end