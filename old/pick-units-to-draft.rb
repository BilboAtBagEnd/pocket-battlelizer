#!/usr/bin/ruby

require 'optparse'
require 'ostruct'

DEFAULT_DRAFTS = 6
SETS = {
    'Ancients-1' => %w(Celts Romans), 
    'Fantasy-1' => %w(Orcs Elves),
}

options = OpenStruct.new
options.armies = []
options.series = []
options.sets = []
options.drafts = DEFAULT_DRAFTS
OptionParser.new do |opts|
    opts.banner = <<-END
Usage: #{$0} [-d DRAFTS] [-s SET ...] [-r SERIES ...] [-a ARMY ...]

Set up drafting rounds for Pocket Battles. 

The armies can be filtered; by default, draft from all armies.

Armies available: 
    #{SETS.values.flatten.sort.join(', ')}

Sets available: 
    #{SETS.keys.sort.join(', ')}

    END

    opts.on('-a', '--army ARMY', "Use units from this army") { |a| options.armies << a }
    opts.on('-p', '--pack PACK', "Use units from a pack (box)") { |s| options.sets << s }
    opts.on('-s', '--series SERIES', "Use units from an entire series") { |s| options.series << s }
    opts.on('-d', '--drafts DRAFTS', "Number of drafts rounds; defaults to #{DEFAULT_DRAFTS}") { |d| options.drafts = d if d > 0 }
end.parse!

if (options.series.size + options.armies.size + options.sets.size) > 0
    wanted_armies = options.armies
    options.series.each do |series|
        SETS.each do |name, armies|
            if (name.split('-')[0] == series) 
                wanted_armies += armies
            end
        end
    end
    options.sets.each do |set|
        SETS.each do |name, armies|
            if (name == set) 
                wanted_armies += armies
            end
        end
    end
    wanted_armies.uniq!
else
    wanted_armies = SETS.values.flatten
end

if wanted_armies.size > 0
    puts "\nUsing the following armies: #{wanted_armies.join(', ')}\n"
else
    puts <<-END
Couldn't find the armies you wanted to use!

If you used -p, did you add the set number to the name (like Fantasy-1)?
If you used -s, did you use only the series name (like Ancients)?
    END
    exit
end

units = []
wanted_armies.each do |army|
    (1..30).each do |n|
        units << "#{army}-#{'%02d' % n}"
    end
end

units = units.sort_by { rand }

puts
(1..(options.drafts)).each do |i|
    draft_units = units.slice!(0, 5)
    puts "Draft #{i}:"
    puts draft_units.sort.join(', ')
    if i < options.drafts
        puts "\nHit enter to continue"
        gets
    else
        puts "\nDone!\n"
    end
end
