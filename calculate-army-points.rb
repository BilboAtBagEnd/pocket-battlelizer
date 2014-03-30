#!/usr/bin/ruby

require 'yaml'
require 'optparse'
require 'pocket-battles-1.0.rb'

OptionParser.new do |opts|
    opts.banner = <<-END
Given input army units, calculates how much your army is worth. 

Available armies:
 - #{PocketBattles.armies.join("\n - ")}

Input your units with separate lines per army as: 

ARMY1 n1 n2 n3...
ARMY2 n1 n2 n3...

Example: 

Celts 1 02 23 28 
Romans 1 2 04 17 30

Press Control-d when you're done.
    END
end.parse!

points = 0
STDIN.each do |line|
    line.strip!
    next if line.empty?

    fields = line.split(/[ ,]+/)
    army_name = fields.shift

    unless PocketBattles.has_army? army_name
        puts "Unknown army #{army_name}; please try again."
        next
    end
    army = PocketBattles.army(army_name)

    fields.each do |n|
        begin
            unit = army.unit n
            puts "#{unit.name} [#{unit.reference}] is worth #{unit.points}"
            points += unit.points
        rescue => e
            puts "Couldn't find unit #{n}, skipping"
            next
        end
    end
    puts
end

puts <<END

Your army is worth #{points} points. 
Your opponent needs to collect #{(points.to_f/2).round} points to win.
END
