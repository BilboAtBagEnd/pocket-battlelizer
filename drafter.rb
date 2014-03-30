#!/usr/bin/ruby -I lib

require 'pocket-battles'

points = 30
armies = []

armies << PocketBattles::Draft.draft_for('Celts', points, 'Compatible')
armies << PocketBattles::Draft.draft_for('Romans', points, 'Compatible')
armies << PocketBattles::Draft.draft_for('Elves', points, 'Compatible')
armies << PocketBattles::Draft.draft_for('Orcs', points, 'Compatible')
armies << PocketBattles::Draft.draft_for('Macedonians', points, 'Compatible')
armies << PocketBattles::Draft.draft_for('Persians', points, 'Compatible')

armies.each {|a| puts a.to_summary(true)}
#armies.each {|a| puts a.to_summary(true)}
#armies.each {|a| puts a }

