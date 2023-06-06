script_directory = File.dirname(__FILE__)
require File.join(script_directory,"Nx.jar")
java_import "com.nuix.nx.NuixConnection"
java_import "com.nuix.nx.LookAndFeelHelper"
java_import "com.nuix.nx.dialogs.ChoiceDialog"
java_import "com.nuix.nx.dialogs.TabbedCustomDialog"
java_import "com.nuix.nx.dialogs.CommonDialogs"
java_import "com.nuix.nx.dialogs.ProgressDialog"
java_import "com.nuix.nx.dialogs.ProcessingStatusDialog"
java_import "com.nuix.nx.digest.DigestHelper"
java_import "com.nuix.nx.controls.models.Choice"

LookAndFeelHelper.setWindowsIfMetal
NuixConnection.setUtilities($utilities)
NuixConnection.setCurrentNuixVersion(NUIX_VERSION)

require 'csv'

load File.join(script_directory,"BatchLoadHelper.rb")
load File.join(script_directory,"TimeSpanFormatter.rb")

batch_load_helper = BatchLoadHelper.new
batch_load_choices = $current_case.getBatchLoads.map do |bl|
	evidence_names = batch_load_helper.find_affected_evidence_names(bl).join("; ")
	label = "#{bl.getLoaded.toString} (#{evidence_names})"
	next Choice.new(bl,label,label,true)
end

dialog = TabbedCustomDialog.new("Batch Load Report")

main_tab = dialog.addTab("main_tab","Main")
main_tab.appendSaveFileChooser("report_csv","Report CSV","Comma Separated Values (*.csv)","csv")
main_tab.appendTextField("date_format","Date Format","YYYY/MM/dd hh:mm:ss aa")
main_tab.appendCheckBox("include_additional_settings","Include 'Additional Settings'",false)
main_tab.appendCheckBox("include_case_evidence_settings","Include 'Case Evidence Settings'",false)
main_tab.appendCheckBox("include_data_processing_settings","Include 'Data Processing Settings'",false)
main_tab.appendCheckBox("include_data_settings","Include 'Data Settings'",false)
main_tab.appendCheckBox("include_parallel_processing_settings","Include 'Parallel Processing Settings'",false)
main_tab.appendChoiceTable("reported_batch_loads","Reported Batch Loads",batch_load_choices)

dialog.validateBeforeClosing do |values|
	if values["reported_batch_loads"].size < 1
		CommonDialogs.showWarning("Please select at least 1 batch load to report on.")
		next false
	end

	if values["date_format"].strip.empty?
		CommonDialogs.showWarning("Please provide a non-empty Date Format value.")
		next false
	end

	# Use exception thrown to determine early whether user provided bad date format string
	begin
		org.joda.time.DateTime.now.toString(values["date_format"])
	rescue Exception => exc
		CommonDialogs.showError("Error in provided Date Format: #{exc.message}")
		next false
	end

	next true
end

dialog.display
if dialog.getDialogResult == true
	values = dialog.toMap

	report_csv = values["report_csv"]
	date_format = values["date_format"]
	reported_batch_loads = values["reported_batch_loads"]
	time_zone = org.joda.time.DateTimeZone.getDefault
	kinds = $utilities.getItemTypeUtility.getAllKinds.map{|kind| kind.getName}

	include_additional_settings = values["include_additional_settings"]
	include_case_evidence_settings = values["include_case_evidence_settings"]
	include_data_processing_settings = values["include_data_processing_settings"]
	include_data_settings = values["include_data_settings"]
	include_parallel_processing_settings = values["include_parallel_processing_settings"]

	ProgressDialog.forBlock do |pd|
		CSV.open(report_csv,"w:utf-8") do |csv|
			# Write headers row
			headers = [
				"Batch Load GUID",
				"Relevant Evidence",
				"Batch Load Start",
				"Batch Load Finish",
				"Batch Load Elapsed",
				"User Short Name",
				"User Long Name",
				"Items",
			]

			headers += kinds.map{|kind| "#{kind.capitalize} Items"}

			# Addtional headers based upon what other '* Settings' groups are selected and the keys present in each
			# groups' map.

			additional_settings_keys = []
			case_evidence_settings_keys = []
			data_processing_settings_keys = []
			data_settings_keys = []
			parallel_processing_settings_keys = []

			sampled_batch = reported_batch_loads.first

			if include_additional_settings
				additional_settings_keys = sampled_batch.getAdditionalSettings.keys
				headers += additional_settings_keys.map{|key|"AdditionalSettings.#{key}"}
			end

			if include_case_evidence_settings
				case_evidence_settings_keys = sampled_batch.getCaseEvidenceSettings.keys
				headers += case_evidence_settings_keys.map{|key|"CaseEvidenceSettings.#{key}"}
			end
			
			if include_data_processing_settings
				data_processing_settings_keys = sampled_batch.getDataProcessingSettings.keys
				headers += data_processing_settings_keys.map{|key|"DataProcessingSettings.#{key}"}
			end

			if include_data_settings
				data_settings_keys = sampled_batch.getDataSettings.keys
				headers += data_settings_keys.map{|key|"DataSettings.#{key}"}
			end

			if include_parallel_processing_settings
				parallel_processing_settings_keys = sampled_batch.getParallelProcessingSettings.keys
				headers += parallel_processing_settings_keys.map{|key|"ParallelProcessingSettings.#{key}"}
			end
			
			csv << headers			

			reported_batch_loads.each_with_index do |batch_load,batch_load_index|
				pd.setMainProgress(batch_load_index+1,reported_batch_loads.size)
				pd.setMainStatusAndLogIt("Collecting Data for Batch Load #{batch_load.getLoaded}")

				batch_load_guid = batch_load.getBatchId
				corresponding_history_event = batch_load_helper.find_history_event_for(batch_load)
				start_date = corresponding_history_event.getStartDate.withZone(time_zone)
				end_date = corresponding_history_event.getEndDate.withZone(time_zone)
				elapsed_seconds = (end_date.getMillis - start_date.getMillis) / 1000
				batch_load_evidence_items = batch_load_helper.find_affected_evidence_items(batch_load)
				user = corresponding_history_event.getUser

				row_values = [
					batch_load_guid,
					batch_load_evidence_items.map{|ei| ei.getLocalisedName}.join("; "),
					start_date.toString(date_format),
					end_date.toString(date_format),
					TimeSpanFormatter.seconds_to_elapsed(elapsed_seconds),
					user.getShortName,
					user.getLongName,
					$current_case.count("batch-load-guid:\"#{batch_load_guid}\""),
				]

				# By kind break down
				row_values += kinds.map{|kind| $current_case.count("batch-load-guid:\"#{batch_load_guid}\" AND kind:#{kind}") }

				# data_processing_settings_keys = []
				# data_settings_keys = []
				# parallel_processing_settings_keys = []

				if include_additional_settings
					row_values += additional_settings_keys.map{|key|batch_load.getAdditionalSettings[key]}
				end

				if include_case_evidence_settings
					row_values += case_evidence_settings_keys.map{|key|batch_load.getCaseEvidenceSettings[key]}
				end

				if include_data_processing_settings
					row_values += data_processing_settings_keys.map{|key|batch_load.getDataProcessingSettings[key]}
				end

				if include_data_settings
					row_values += data_settings_keys.map{|key|batch_load.getDataSettings[key]}
				end

				if include_parallel_processing_settings
					row_values += parallel_processing_settings_keys.map{|key|batch_load.getParallelProcessingSettings[key]}
				end

				csv << row_values
			end
		end

		pd.setCompleted
	end
end