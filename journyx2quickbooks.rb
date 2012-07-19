require 'yaml'
require 'awesome_print'
require 'date'

NOT_FOUND = "not found!"

def read_settings
	settings 						= YAML.load_file("settings.yml")
	@journyx_path 			= settings["journyx_reports"]
	@export_path 				= settings["export_files_to"]
	@templates_path			= settings["template_file"]
end

def load_customers_project
  
   company_project_list = Hash.new { |hash, key| hash[key] = [] } 

  File.open("data_files/timerlist.IIF").each do |line| 
    
    if line.slice(0, 4) == "CUST" and line.include? ":"

      strline = line.gsub('"', '') .split(":")
      company = strline[0].gsub('CUST', '').strip
      project = strline[1].match(/(PJ+\w+)/).to_s

      unless project.nil? or project.empty?

        if company_project_list.has_key?(company)
          
          if !company_project_list[company].include? project
            company_project_list[company] << project
          end

        else
          company_project_list[company] << project
        end

      end

    end

  end 

  company_project_list

end

@companies = load_customers_project

def get_company_name(project_name)

	company_name = NOT_FOUND

	@companies.each do |key, value| 
		if value.include?(project_name)
	  	company_name = key
	  	break
	 	end
	end

	company_name

end

def make_company_project_list(project_list)
	company_projetc_list = []

	project_list.each do |proj|
		company_name = get_company_name(proj)
		company_project_name = "#{company_name}:#{proj}"

		unless company_name == NOT_FOUND
			company_projetc_list << company_name if !company_projetc_list.include?(company_name)
			company_projetc_list << company_project_name if !company_projetc_list.include?(company_project_name)
		end

	end

	company_projetc_list
end

read_settings


template_file 		= File.read(@templates_path)

project_list 				= []
project_name 				= ""
task_list 					= []
not_found_projects 	= []
task_name 					= ""
currente_date 			= DateTime.now.strftime('%m/%d/%Y') 

newFileArray = []

customer_list = []

if !File.exists?(@journyx_path)
	puts "JournyX Report File not found!" 
else

	File.open(@journyx_path).each { |line| 

		strline = line.split("	")

		item_name 		= strline[0].strip
		hours 				= strline[1].to_f
		description 	= strline[3].to_s.gsub('\r\n', "").strip #maybe chomp??


		if item_name.slice(0, 6) == "....PJ" && hours > 0

			project_name = item_name.gsub(".", "")
			project_list << project_name if !project_name.empty?
			
		elsif item_name.slice(0, 6) == "......" && hours > 0

			task_name = description.empty? ? item_name.gsub(".", "") : description
			task_name.gsub!(/([0-9]+[\s])/,'')

		elsif item_name.include? "subtotal for" and !project_name.empty? and !task_name.empty?

			employee_name = item_name.gsub("subtotal for", "").strip	
			company_name = get_company_name(project_name)

			if company_name == NOT_FOUND
				not_found_projects << "#{project_name} - #{company_name} - #{hours} - #{task_name} - #{employee_name}\n"
			else
				task_list << "TIMEACT	#{currente_date}	#{company_name}:#{project_name}	JournyX	Engineering Service (by CPS)		#{hours}		#{task_name} - #{employee_name}	N	1\n"
			end

		end

		task_name = "" if line.strip.empty?
	}


	newstring = ""
	make_company_project_list(project_list).map { |e| newstring += "CUST	#{e}\n" }
	newstring = newstring.slice(0, newstring.length - 1)


	newstring2 = ""
	task_list.map { |e| newstring2 += e }

	template_file = template_file.gsub("#CUSTOMER_LIST#", newstring)
	template_file = template_file.gsub("#TASK_LIST#", newstring2)

	not_found_file = ""
	not_found_projects.map { |line| not_found_file += line }

	File.open(File.join(@export_path, "quickbooks_#{DateTime.now.strftime('%Y%m%d')}.txt"), "w") {|file| file.puts template_file}
	File.open(File.join(@export_path, "quickbooks_not_found_#{DateTime.now.strftime('%Y%m%d')}.txt"), "w") { |file| file.puts not_found_file }
end
