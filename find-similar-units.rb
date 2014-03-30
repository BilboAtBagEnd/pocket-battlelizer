#!/usr/bin/ruby

require 'optparse'
require 'pocket-battles-1.0.rb'

OptionParser.new do |opts| 
    opts.banner = <<-END
Finds units similar in all armies. Useful to find strange oddities 
in scoring and point values.
    END
end.parse!

UNITS = {}

PocketBattles::ARMIES.each_value do |army|
    army.units.each_value do |unit|
        next unless unit.has_all_info?
        
        unit_key = "s:#{unit.shooting}:e:#{unit.engagement}:f:#{unit.formation}:w#{unit.wounds if unit.wounds}:p:#{unit.powers.join(',') if unit.powers}"
        UNITS[unit_key] = [] unless UNITS.has_key? unit_key
        UNITS[unit_key] << unit
    end
end

UNITS.keys.sort.each do |key|
    unit_list = UNITS[key]
    next unless unit_list.size > 1

    total_points = 0
    unit_list.map { |unit| total_points += unit.points }
    next unless (total_points.to_f / unit_list.size) != unit_list[0].points.to_f

    puts "Similar units for '#{key}' : "
    unit_list.each do |unit|
        puts "\t#{unit.army.name}: #{unit.name} - worth #{unit.points}"
    end
end

