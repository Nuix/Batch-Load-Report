class BatchLoadHelper
	def initialize
		@load_data_history = $current_case.getHistory({"type" => "loadData"})
	end

	def find_history_event_for(batch_load_details_object)
		# It appears that the corresponding history event end datetime corresponds to the
		# batch load's value returned by BatchLoadDetails.getLoaded.  Unfortunately the times
		# don't seem to be consistently identical, differing by a second or 2, so rather than
		# exact matching, we assume the HistoryEvent.getEndDate and the BatchLoadDetails.getLoaded
		# times with the smallest difference means they are a match.  The only way I forsee this approach
		# having an issue is if somehow 2 or more batch loads finished within seconds of each other.
		
		# Sort events basically by how far away in time the given event ended compared to the
		# given batch load details loaded date time
		sorted_events = @load_data_history.sort_by do |history_event|
			history_event_end_millis = history_event.getEndDate.getMillis
			batch_load_loaded_millis = batch_load_details_object.getLoaded.getMillis
			next (history_event_end_millis - batch_load_loaded_millis).abs
		end

		# Return the first event in our sorted list, being sorted ascending, the first
		# history event should be the nearest in time to when when the batch load completed
		return sorted_events.first
	end

	def find_affected_evidence_items(batch_load_details_object)
		batch_load_guid = batch_load_details_object.getBatchId
		evidence_query = "mime-type:\"application/vnd.nuix-evidence\" AND batch-load-guid:\"#{batch_load_guid}\""
		batch_load_evidence_items = $current_case.searchUnsorted(evidence_query)
		return batch_load_evidence_items
	end

	def find_affected_evidence_names(batch_load_details_object)
		return find_affected_evidence_items(batch_load_details_object).map{|ei|ei.getName}
	end
end