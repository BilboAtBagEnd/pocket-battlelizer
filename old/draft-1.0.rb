#!/usr/bin/ruby

require 'pocket-battles-1.1.rb'

module PocketBattles
    module Draft
        class DraftedArmy < Array
            attr_reader :name

            def initialize(name = '')
                @name = name
            end

            def to_s 
                "[#{(self.map { |f| f.join(',') }).join('],[')}]"
            end

            def _unit_to_s(u)
                s = "#{u.name} #{u.reference} "
                if u.shooting.size > 0 
                    s += "s#{u.shooting} "
                end
                if u.engagement.size > 0
                    s += "e#{u.engagement} "
                end
                s += "(#{u.points})[#{u.formation}] !#{u.wounds}!"
                if u.powers.size > 0 
                    s += " {#{u.powers.join('|')}}"
                end
                s
            end

            def _formation_to_s(f)
                (f.map { |u| _unit_to_s u }).join(', ')
            end

            def pretty_print
                puts "<#{@name} size = #{self.size} points = #{self.flatten.inject(0) { |memo, u| memo + u.points }}" 
                self.each do |f|
                    puts "\t- #{_formation_to_s f}"
                end
                puts '>'
            end

            def validate
                errors = []

                self.each do |f|
                    if f == nil
                        errors << 'Nil formation!' 
                    else
                        nice_f = _formation_to_s f

                        total_wounds = f.inject(0) { |t,u| t + u.wounds }
                        non_aux_units = f.select { |u| !u.powers.include?('Auxiliary') }
                        min_formation = (non_aux_units.map { |u| u.formation }).min

                        errors << "#{nice_f}: has 0 wounds!" if total_wounds == 0
                        errors << "#{nice_f}: has bad formation (must be #{min_formation})!" if non_aux_units.size > min_formation
                    end
                end

                unless errors.empty? 
                    raise "Drafted army validation errors: #{errors.join(', ')}"
                end
            end
        end

        # Does a very stupid drafting: 
        #
        # 1. Shuffle all the units in the army
        # 2. Iterate through, picking and adding a unit to a formation 
        #    until we've either run out of formation points or army points.
        # 3. We'll stop forming a unit if we run into a unit that can't 
        #    fit into the formation instead of, say, setting the formation 
        #    to the side or something smrt like that. But it will tend to 
        #    lead to more single units for soaking capabilities.
        # 4. At least we recycle units.
        # 5. On the other hand, we will always try to include aux units.
        # 6. At least we try our hardest not to create invalid draft armies. 
        #
        class StupidDraft
            STARTING_FORMATION_VALUE = 100 # must exceed any single unit formation value

            def initialize(army_name, army_points, debug = false) 
                @army_name = army_name
                @army_points = army_points
                @debug = debug
                @units = PocketBattles.army(@army_name).units.clone
            end

            def draft 
                skipped_units = []
                aux_units = @units.select { |u| u.powers.include? 'Auxiliary' }
                units = @units.reject { |u| u.powers.include? 'Auxiliary' }

                aux_units.shuffle!
                units.shuffle!

                formations = DraftedArmy.new(@army_name)
                current_formation = []
                current_formation_value_min = STARTING_FORMATION_VALUE
                current_total_wounds = 0

                # We assume that if we have any aux units, we'll use them
                points_left = @army_points - (aux_units.inject(0) { |t,u| t + u.points })

                while points_left > 0
                    if units.empty? 
                        if skipped_units.empty? 
                            break
                        elsif (skipped_units.inject(0) { |t,u| t + u.wounds }) == 0
                            break
                        else
                            units = skipped_units.shuffle
                            skipped_units = []
                        end
                    end

                    unit = units.shift
                    break if !unit 

                    if unit.powers.include? 'Auxiliary'
                        aux_units << unit
                        next
                    end

                    if @debug
                        puts "Current formation: #{current_formation.join(',')}" 
                        puts "Processing #{unit}"
                    end

                    if points_left < unit.points 
                        puts "Can't fit unit into #{points_left} points left, dropping" if @debug
                        next

                    elsif points_left - unit.points < 0 
                        #units << unit
                        puts "Only #{points_left} points left: skipping" if @debug
                        skipped_units << unit
                        next

                    elsif ((current_formation.size + 1) > current_formation_value_min) || 
                          (current_formation.size >= unit.formation) 

                        puts "Would exceed formation value #{current_formation_value_min}" if @debug

                        if (current_total_wounds < 1) 
                            puts "Cannot end formation because not enough wounds in formation; skipping unit" if @debug
                            skipped_units << unit
                            next
                        end

                        formations << current_formation unless current_formation.empty?
                        if @debug
                            puts "Creating new formation"
                            puts formations.pretty_print
                        end
                        current_formation = []
                        current_formation_value_min = STARTING_FORMATION_VALUE
                        current_total_wounds = 0
                    end

                    if (current_formation.empty? and unit.wounds < 1) 
                        puts "Will not create formation with initial unit wounds=0, skipping" if @debug
                        skipped_units << unit
                        next
                    end

                    current_formation << unit 
                    current_formation_value_min = unit.formation if unit.formation < current_formation_value_min
                    current_total_wounds += unit.wounds

                    points_left -= unit.points
                end

                if current_formation 
                    formations << current_formation
                end

                # Slightly smrt handling of auxiliary units.

                # Sprinkle in auxiliary units, focusing on units with formation value 1 and wounds 1
                formations.each do |f|
                    break if aux_units.empty? 
                    f << aux_units.shift if (f.size == 1 and f[0].formation == 1 and f[0].wounds == 1)
                end
                # If aux left, focus next on units with formation value 1 and any wounds
                formations.each do |f|
                    break if aux_units.empty? 
                    f << aux_units.shift if (f.size == 1 and f[0].formation == 1)
                end
                # If aux left, add to any other units without an aux
                formations.each do |f| 
                    break if aux_units.empty? 
                    f << aux_units.shift unless (f.inject([]) { |m, u| m + u.powers  }).include? 'Auxiliary'
                end

                formations
            end
        end
    end
end

points = 60
PocketBattles.army_names.each do |a|
    da = PocketBattles::Draft::StupidDraft.new(a, points).draft
    da.pretty_print
    da.validate
end
