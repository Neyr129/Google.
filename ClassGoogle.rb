 
#!/usr/bin/env ruby

#  														 На выход идет массив вида:
# 														     массивhReturn	
#
# [  [ ["abc", "11111\n"], [], ["abc", "\n"],   "!!!FILENAME!!!"  ]   [  [ssabcsssssss],[abc], [] [ffffffff], "!!!FILENAME!!!" ]  ]
#     \ \__________ ___/   \/	\_________/   		             /     \  \__________/	\_/   \/  \______/ 		              /
#      \     str1	      str2		str3   	  		     	    /	  	\	    str1      str2  str3	str4                 /
#       \______________________________________________________/	     \__________________________________________________/
#                     			 |													         	   |
#         		     	 	   File1								           		   		     File2	
#
require 'pry'
require 'zlib'

class String 
	def red 
		"\e[31m#{self}\e[0m" 
	end

	def green 
		"\e[42m#{self}\e[0m" 
	end
end

class Google



	####################################################
	##### определяет поиск по папке или по файлу #######
	# для командной строки
	def search_args					    
		@srch = ARGV[-2]
		@path   = ARGV[-1]
		if ARGV.include?('-R')		 				
			searchReturn = folderSearch
		else
			searchReturn = fileSearch
		end		
		showResult(searchReturn)
	end

	####################################################
	##### определяет поиск по папке или по файлу #######
	# для обычного ввода
	def search(argSrch, argPath)					    
		@srch =argSrch
		@path   = argPath
		if ARGV.include?('-R')		 				
			searchReturn = folderSearch
		else
			searchReturn = fileSearch
		end		
		showResult(searchReturn)
	end

	######################################################
	############# поиск по одному файлу ##################
	def fileSearch
		numb = 0   
		#количество строк для -А
		ARGV.each()  { |arg| numb  = arg.scan(/[0-9]*/)[0]  if arg.match(/^[\d]+$/) }
		numb = numb[0].to_i 
		#чтение файла				
		searchReturn = Array.new
		file = (@path)
		if File.directory?(file)
			puts 'Это каталог! Добавьте -R'.red  
			exit
		end
		begin
			if /.gz/.match(file)
				if ARGV.include?('-Z')
						f1 = Zlib::GzipReader.open((File.expand_path(file))) 
				else 
					puts 'чтобы открыть архив добавьте аргумент -Z'.red
					exit
				end
			else
				if ARGV.include?('-Z')
					puts 'Это не архив!'.red
					exit
				else
					f1 = File.open(File.expand_path(file))	
				end
			end
		rescue
			puts 'Такого файла не существует!'.red
			exit
		end
		@sf = f1.readlines
		#получить массив с номерами искомых подстрок
		pos = Array.new(@sf.length){Array.new}
		if ARGV.include?('-e')
			pos = eGetPositions
		else		
			pos = getPositions
		end
		#сформировать конечную строку
		searchReturn[0] = stringForm(pos)
		# доп.строки при аргументе -А
		addStrings(searchReturn[0], numb) if ARGV.include?('-A')		
		searchReturn[0].push(file) # добавляет в конец строки название файла
		return searchReturn;
	end

	#######################################################
	###########    поиск по папке  ########################
	def folderSearch
		numb = 0  
		# количество строк для -А
		ARGV.each  { |arg| numb  = arg.scan(/[0-9]*/)[0]  if arg.match(/^[\d]+$/) }
		numb = numb[0].to_i  
		searchReturn = Array.new	
		#чтение файла				
		if File.directory?(@path)
			Dir.chdir(@path)
			d = Dir.new(@path) 			
			entries = (d.entries.select {|entry| !File.directory?(entry)})
			entries.each_with_index do |file, i| 
				if /.gz/.match(file)
					if ARGV.include?('-Z') 
						f1 = Zlib::GzipReader.open((File.expand_path(file))) 
					else
						searchReturn[i] = [""]
						next
					end
				else				
					f1 = File.open(File.expand_path(file))
				end
				@sf = f1.readlines					
				#получить массив с номерами искомых подстрок	
				pos = Array.new(@sf.length){Array.new}
				if ARGV.include?('-e')
					pos = eGetPositions
				else
					pos = getPositions
				end
				#сформировать конечную строку
				searchReturn[i] = stringForm(pos)			
				# доп.строки при аргументе -А
				addStrings(searchReturn[i], numb) if ARGV.include?('-A')				
				searchReturn[i].push(file)#добавляет в конец строки название файла
			end
		else 
			puts 'Это не каталог! Уберите -R'.red
			exit
		end
		return searchReturn
	end

	###############################################################
	############# определить позиции искомых подстрок #############
	def getPositions
		positions = Array.new(@sf.length){Array.new}
		@sf.each_with_index do |string, currStr| 		
			positions[currStr][0] = string.index(@srch)
			#искать до тех пор, пока check находит следующее значение, чтобы не получить исключение
			check = string.index(@srch, positions[currStr][0]+1)  if positions[currStr][0] != nil
			i = 0
		 	while check != nil
				i += 1
				nextPos = positions[currStr][i-1]+1
			    positions[currStr][i] = string.index(@srch, nextPos)
			    check = string.index(@srch, positions[currStr][i]+1)
			end
		end

		return positions
	end

	#######################################################################################
	###############определить позиции искомых подстрок для рег.выражений (-e) #############
	def eGetPositions
	   	@positions = Array.new(@sf.length){Array.new}
		@sf.each_with_index do |string, currStr| 		
			@positions[currStr][0] = string.index(/#{@srch}/)
			check = string.index(/#{@srch}/, @positions[currStr][0]+1)  if @positions[currStr][0] != nil
			i = 0
		 	while check != nil
				i += 1
				nextPos = @positions[currStr][i-1]+1
			    @positions[currStr][i] = string.index(/#{@srch}/, nextPos)
			    check = string.index(/#{@srch}/, @positions[currStr][i]+1)
			end
		end
	    return @positions
	end
	
	
	#########################################################################
	#############  	      Окраска найденных подстрок                 #######	
	def stringForm(positions)
		str = Array.new(@sf.length){ Array.new }		
		searchl = @srch.length   
		positions.each_with_index do |string,currStr|
			i = -1
			#если в строке нет совпадений, пометим ее как пустую []
			if string[0] != nil
				#если искомая подстрока не в самом начале, то делаем белый текст до ее позиции
				if string[0] > 0
			    	i += 1
					str[currStr][i] = @sf[currStr][0 .. string[0]-1] 
				end
				string.each_with_index do |empty_arg, currPos| 						
					#чтобы подкрашивало подстроки найденные с помощью рег.выражений
					if ARGV.include?('-e')
						searchl = @sf[currStr].scan(/#{@srch}/)[currPos].length
					end
					i += 1
					#найденное красить красным
					str[currStr][i] = @sf[currStr][string[currPos] .. string[currPos] + searchl-1].red
					#определить явлется ли следующая позиция последней
					if currPos < string.length-1 
						nextPos = string[currPos + 1] -1
					else
						nextPos = @sf[currStr].index("\n")
					end
					i += 1
					str[currStr][i] = @sf[currStr][string[currPos] + searchl .. nextPos]
				end 
			else
				str[currStr] = []
			end
		end
	return str
	end

	#####################################################
	#############   Аргумент "-A"  ######################
	#(расставляем метки(111) в соседние строки)
	def addStrings(strings, numb)
		strings.each_with_index	do |string, currStr|
			if !string.empty?   && string != [111]
				(currStr+1).upto(currStr+numb) do |i|						
					strings[i][0] = 111 if  i < strings.length && strings[i].empty?   
				end

				(currStr-1).downto(currStr-numb) do |i|						
					strings[i][0] = 111 if  i >= 0 && strings[i].empty?   
				end
			end
		end	
		##по меткам вставляем дополнительные строки
		strings.each_with_index	do |string, currStr|
			if string[0] == 111
				string[0] = @sf[currStr]
			end
		end
	end

	#########################################################
	######## вывести все это дело ###########################
	def showResult(answer)
		puts 	 		
			
		answer.each_with_index  do |ans, fileNumber|
			#чтобы не выводило имя файла, если в нем ничего не найдено или это архив 
			if (ans[0] != "") && !(ans.first(ans.length - 1).all?{ |a| a.empty? })
				puts ans[ans.length-1].green	
				puts '*'*100 					
				ans.each_with_index do |an, i| 
					next if i == ans.length-1  # в последней строке записано название файла
					an.each do |a|
						print a
					end
				end
				puts '*'*100 					
			end
		end
	end

                                     

 	
end
