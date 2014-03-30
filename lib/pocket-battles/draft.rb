#!/usr/local/bin/ruby

require 'pocket-battles/types'

#
# Drafting logic for PocketBattleizer.
#
# Most basic form is: 
#
#   army = PocketBattles::Draft.draft_for(faction, points, strategy)
#
# You can also directly use the basic ArmyDrafter: 
#
#   army = PocketBattles::Draft::ArmyDrafter.new(faction, points, strategy).draft
#
# There are some specialized army drafters for specific armies and 
# very specific army strategy. 
#
#   army = PocketBattles::Draft::Celts.new(points, strategy).draft 
#   army = PocketBattles::Draft::CeltsFastGaesatae.new(points, strategy).draft 
#
# For more on creating your own drafters, see the ArmyDrafter class. 
#
module PocketBattles
  module Draft

    #
    # Basic strategies for drafting. 
    #
    # Stupid - single-troop units up until the point total. 
    # Compatible - create multi-troop compatible units with ability to seed draft
    #
    module Strategy
      STUPID = 'Stupid'
      COMPATIBLE = 'Compatible'
    end

    #
    # Catch-all basic drafting for any faction.
    #
    # Note: if there is an ArmyDrafter named after a given faction, 
    # it'll likely be used by default here. 
    #
    # Parameters:
    #   faction_name - name of faction to draft from
    #   points - number of points to draft to 
    #   strategy - drafting strategy to use; defaults to STUPID.
    #
    def Draft.draft_for(faction_name, points, strategy = Strategy::STUPID, seed_units = nil)
      if not PocketBattles.is_faction?(faction_name) 
        raise "#{faction_name} is invalid faction!"
      end

      case faction_name
      when 'Celts'
        Celts.new(points, strategy, seed_units).draft
      when 'Romans'
        Romans.new(points, strategy, seed_units).draft
      when 'Elves'
        Elves.new(points, strategy, seed_units).draft
      when 'Orcs'
        Orcs.new(points, strategy, seed_units).draft
      when 'Macedonians'
        Macedonians.new(points, strategy, seed_units).draft
      when 'Persians'
        Persians.new(points, strategy, seed_units).draft
      else
        ArmyDrafter.new(faction_name, points, strategy, seed_units).draft
      end
    end

    #
    # Basically a smart closure that does basic army drafting. If you want 
    # to use it for multiple draft calls, call reset beforehand. 
    #
    # Subclasses can optionally override the following methods: 
    #
    #   seed_open_units() - defaults to converting @seed_units
    #     
    #     For those who want even more control/logic/smrtness in 
    #     starting with an open unit. Set @open_units to an 
    #     array of troop objects from @troops. 
    #
    #     ArmyDrafter will automatically take care of removing the troops in 
    #     @open_units from @troops before drafting, so you don't have to.
    #
    #   is_adding_troop_to_unit_smart?(unit, troop) - defaults to base compatibility 
    #
    #     For those who want to add more logic into whether we should add 
    #     a troop to a unit. For example, maybe the unit contained 
    #     a special troop you wanted to only pair with beefy 2+ wound troops. 
    #
    #     Return true if we should add the given troop to the unit.
    #
    #   recycle_troop?(troop) - defaults to false 
    #
    #     A few troops draft better if we re-insert them to the @troops pool rather than 
    #     sticking them into their own unit straight away, due to 
    #     the one-way effects of some heuristics checks. Good examples: troops 
    #     that can either enhance engagement and/or shooting, but need to be 
    #     part of a troop to be at all effective; it's easier to evaluate 
    #     if it's smart to add them *to* an existing troop than the other way 
    #     around.
    #
    #     Note: we recycle at most three times before giving up.
    #
    #   skip_troop?(troop) - defaults to false
    #
    #     Return true if, based on the entire state of this class during 
    #     drafting, whether we want to entirely remove a troop from 
    #     consideration when we run across it. Example: only have X number 
    #     of catapult-like troops.
    #
    # The following fields aren't meant for consumption outside of this class's 
    # offspring, but just in case....
    #
    # Unchanging fields:
    #
    #   faction - Faction object created from the given faction_name in constructor
    #   points - number of points to draft to 
    #   strategy - strategy to use by drafter
    #
    # Fields used as variables during drafting
    #
    #   army - army object being created during draft
    #   troops - array of troops left as draft proceeds
    #   points_left - number of points left as draft proceeds
    #   open_units - for non-Stupid strategy, unit not yet full
    #
    # Fields useful for child classes to override
    #
    #   seed_units - list of troop reference lists representing initial units
    #
    # Useful externally
    #
    #   debug - whether extra debugging is spit to STDOUT during draft
    #   debug_log - the debugging log, a list of logs
    #
    class ArmyDrafter
      attr_reader :faction, :points, :strategy
      attr_accessor :debug, :seed_units, :debug_log

      def initialize(faction_name, points, strategy = 'Stupid', seed_units = nil)
        @faction = PocketBattles.get_faction(faction_name)
        @points = points
        @strategy = strategy

        @debug = false
        @debug_log = []
        @seed_units = seed_units || []
        puts "seed_units = #{@seed_units}" if @debug

        self.reset
      end

      # reset this object for another drafting go
      def reset
        @army = Army.new
        @troops = @faction.troops.clone
        @points_left = @points

        # 'Compatible' strategy only
        @open_units = []
      end

      # override; see class comment
      def is_adding_troop_to_unit_smart?(unit, troop)
        if troop.is_aux_troop?
          puts "Auxiliary troop!" if @debug
          return true
        end

        remaining_formation_points = unit.min_formation_points - unit.size
        min_variety_needed = remaining_formation_points > 1 ? 2 : 3
        good_enough_variety = remaining_formation_points > 1 ? 3 : 4 

        if unit.is_compatible_with_troop? troop
          puts "- troop is baseline compatible at least" if @debug

          if troop.is_fighting_troop? and (not unit.is_fighting_unit?)
            puts "- troop adds fighting to a non-fighting unit" if @debug
            return true
          end

          if unit.is_engagement_unit?
            puts "- unit has engagement dice" if @debug
            if troop.is_engagement_troop? or troop.has_engagement_compatible_powers?
              puts "- troop has engagement dice or powers" if @debug

              if adds_engagement_variety?(unit, troop, good_enough_variety, min_variety_needed)
                puts "- troop will enhance engagement!" if @debug
                return true
              end
            end
            puts "- troop will not enhance engagement" if @debug
          else 
            puts "- unit is not engagement" if @debug
          end
             
          if unit.is_shooting_unit? 
            puts "- unit has shooting dice" if @debug

            if troop.is_shooting_troop? or troop.has_shooting_compatible_powers?
              puts "- troop has shooting dice or powers" if @debug

              if adds_shooting_variety?(unit, troop, good_enough_variety, min_variety_needed)
                puts "- troop will enhance shooting!" if @debug
                return true
              end
            end
            puts "- troop will not enhance shooting" if @debug
          else
            puts "- unit is not shooting" if @debug
          end

        end

        false
      end

      # override; see class comment
      def seed_open_units
        @seed_units.each do |unit_as_refs|
          u = Unit.new 
          unit_as_refs.each do |ref|
            u.add_troop(@troops.find {|t| t.reference == ref})
          end
          @open_units << u
        end
      end

      # utility method, sums points across all units in 
      # the given array of units.
      def sum_points(units)
        units.inject(0){|memo, u| memo + u.points}
      end

      # utility method, returns whether adding a troop to the unit would 
      # result in a greater variety of engagement dice (and thus a better 
      # chance of a hit per die). 
      def adds_engagement_variety?(unit, troop, good_enough = nil, at_least = nil)
        unit_variety = unit.engagement_dice.uniq.size 
        if good_enough and (unit_variety >= good_enough)
          puts "Good enough engagement variety #{unit_variety}" if @debug
          true
        else
          new_variety = (unit.engagement_dice + troop.engagement).uniq.size
          if at_least and (new_variety < at_least) 
            puts "Need at least variety #{at_least}, new variety is only #{new_variety}" if @debug
            false
          else
            puts "Testing old variety #{unit_variety} < new variety #{new_variety}" if @debug
            unit_variety < new_variety
          end
        end
      end

      # utility method, returns whether adding a troop to the unit would 
      # result in a greater variety of shooting dice (and thus a better 
      # chance of a hit per die). 
      def adds_shooting_variety?(unit, troop, good_enough = nil, at_least = nil)
        unit_variety = unit.shooting_dice.uniq.size
        if good_enough and (unit_variety >= good_enough)
          puts "Good enough shooting variety #{unit_variety}" if @debug
          true
        else
          new_variety = (unit.shooting_dice + troop.shooting).uniq.size
          if at_least and (new_variety < at_least) 
            puts "Need at least variety #{at_least}, new variety is only #{new_variety}" if @debug
            false
          else
            puts "Testing old variety #{unit_variety} < new variety #{new_variety}" if @debug
            unit_variety < new_variety
          end
        end
      end

      # helpful debug status if @debug is true
      def debug_draft_status
        puts <<-END
open_units #{(sum_points @open_units)} + army #{@army.points} + points_left #{@points_left} = #{(sum_points @open_units) + @army.points + @points_left} total points
open units: \n - #{@open_units.join("\n - ")}
#{@army}
---
        END
      end

      # see class comment
      def recycle_troop? troop
        false
      end

      # additional conditions as to whether to skip a particular troop. 
      def skip_troop? troop
        false
      end

      # Put aside seeded units from the troop pool we're iterating 
      # through during draft.
      def reserve_seed_units
        troop_refs_seeded = (@open_units.inject([]) {|memo, u| memo + u.troops}).map {|t| t.reference}
        @troops.reject! { |t| troop_refs_seeded.include? t.reference }
        @points_left -= sum_points(@open_units)
        @troops.shuffle!
      end

      # Returns an Army drafted from the initially given faction in the constructor.
      # Raises an exception if the army doesn't validate post-drafting.
      def draft 
        return @army if @army.size > 0

        puts "Starting with #{@points_left} points" if @debug

        case @strategy

        # Very stupid draft that only picks individual troops
        when Strategy::STUPID
          @troops.shuffle!
          while @points_left > 0
            u = @troops.shift
            @army.add_unit(Unit.new([u]))
            @points_left -= u.points
          end

        # Slightly smarter draft that creates units with first-found compatible troops
        # See also class comment. 
        when Strategy::COMPATIBLE

          seed_open_units
          # Now modify other variables to take into account removing troops in opening unit(s)
          # from drafting consideration
          reserve_seed_units

          # map of troop reference -> number of times cycled.
          recycled_troops = {}

          if @debug
            debug_draft_status
          end

          while (@points_left > 0) and (not @troops.empty?)
            t = @troops.shift

            puts "#{@points_left} points left: Considering troop #{t}" if @debug

            next if (t == nil) or (@points_left - t.points < 0) or (skip_troop? t)

            # Try to find an open unit to add this troop to...
            added_troop_to_unit = nil
            @open_units.each do |u|
              puts "Considering putting #{t} in #{u}" if @debug
              unless u.can_add_troop? t
                puts "Can't add to unit" if @debug
                next
              end
              if (u.can_add_troop? t) and (is_adding_troop_to_unit_smart? u, t)
                u.add_troop(t)
                added_troop_to_unit = u
                break
              end
            end
            # ... otherwise add it to open units as its own unit.
            if not added_troop_to_unit
              print "No smart unit to add troop to, " if @debug
              if recycle_troop? t
                if !(recycled_troops.has_key?(t.reference)) 
                  recycled_troops[t.reference] = 0
                elsif recycled_troops[t.reference] >= 3
                  puts "not recycling troop, exceeded retries" if @debug
                  next
                end
                puts "recycling troop" if @debug
                @troops.insert((rand @troops.size)+1, t)
                recycled_troops[t.reference] += 1
                next
              else
                u = Unit.new [t]
                @open_units << u
                puts "creating new unit #{u}" if @debug
              end
            else
              puts "Added to unit #{added_troop_to_unit}" if @debug
            end

            puts "Successfully added troop." if @debug
            @points_left -= t.points

            # Clear out all full units from @open_units and 
            # put them into the army
            full_units = @open_units.select {|u| u.is_full?}
            @open_units.reject! {|u| u.is_full?}
            unless full_units.empty?
              puts "Moving to army from open_units: #{full_units.join(',')}" if @debug
              full_units.each {|u| @army.add_unit u}
            end

            debug_draft_status if @debug
          end

          # If any units are left over, they're in the army now!
          puts "Merging open_units with army" if @debug
          @open_units.each {|u| @army.add_unit u}


        # No other strategies known just yet
        else
          raise "Can't handle strategy #{strategy} yet!"
        end

        debug_draft_status if @debug

        begin 
          @army.validate
        rescue => e
          raise "Got invalid army: #{e}"
        end

        @army
      end
    end

    #
    # An army drafter built for the Celts. It's quite simply, really: 
    #
    #   1. Always have both Gaesatae in separate units.
    #   2. Always add something with at least 2 wound points to each 
    #    of the Gaesatae units.
    #
    class Celts < ArmyDrafter
      POINT_LEVEL_TRIGGERS_SMART_ROUTINES = 50

      def initialize(points, strategy, seed_units = nil)
        # The two Gaesatae. If there were more, I'd put them ALL here.
        super 'Celts', points, strategy, (points < POINT_LEVEL_TRIGGERS_SMART_ROUTINES ? seed_units : (seed_units || [ %w(Celts-06), %w(Celts-05) ]))
      end

      def recycle_troop? troop
        troop.name == 'Warchief'
      end

      def is_adding_troop_to_unit_smart?(unit, troop)
        if @points >= POINT_LEVEL_TRIGGERS_SMART_ROUTINES and (unit.troops.find {|t| t.name == 'Gaesatae'})
          puts "Special consideration for Gaesatae" if @debug
          if @troops.empty? 
            # Last chance to add a troop!
            return true
          elsif (troop.is_aux_troop? and troop.wounds > 0) #or # Always welcome aux troops with wounds!
              #(troop.wounds > 1)             # if we're weak, we want some beefcake
              adds_engagement_variety? unit, troop
          elsif adds_engagement_variety? unit, troop
            return true
          else
            return false
          end
        elsif unit.troops.find {|t| t.name == 'Warchief'}
          puts "Special consideration for Warchief" if @debug
          if @troops.empty? 
            true
          else 
            troop.engagement.uniq.size > 1
          end
        else
          super unit, troop
        end
      end
    end

    #
    # An army drafter for the Celts that's even simpler. 
    #
    #  1. Always have Gaesatae paired with a fast Horsemen 
    #   that increases their engagement hit probability.
    #
    class CeltsFastGaesatae < Celts
      def initialize(points, strategy, seed_units = nil)
        super points, strategy, 
          (seed_units ||= [ %w(Celts-06 Celts-14), %w(Celts-05 Celts-12) ])
      end
    end

    #
    # An army drafter for the Romans.
    #
    #  1. For each 40 points of troops, have only one catapult.
    #
    class Romans < ArmyDrafter
      CATAPULTS = %w(Romans-03 Romans-04 Romans-05)

      def initialize(points, strategy, seed_units = nil)
        super 'Romans', points, strategy, seed_units
      end

      def reset
        super
        @number_catapults = @points / 40
        puts "Max number of catapults to use: #{@number_catapults}" if @debug
      end

      def is_catapult_troop? troop
        CATAPULTS.include? troop.reference
      end

      def recycle_troop? troop
        troop.name == 'Aquilifer'
      end

      def skip_troop? troop
        if is_catapult_troop? troop
          puts "#{troop} is a catapult!" if @debug
          existing_catapults = ((@open_units + @army.units).inject([]) { |memo, u| memo + u.troops}).select {|t| is_catapult_troop? t }
          puts "Existing catapults: #{existing_catapults}" if @debug
          (existing_catapults.size + 1) > @number_catapults
        else 
          super 
        end
      end
    end

    #
    # An army drafter for the Elves. 
    #
    #  1. Pathfinders have to be more carefully handled. Don't let them be their own faction; 
    #   recycle them.
    #
    class Elves < ArmyDrafter
      def initialize(points, strategy, seed_units = nil)
        super 'Elves', points, strategy, seed_units
        @max_single_troop_units = points / 30
        @num_single_troop_units = 0
      end

      def skip_troop? troop
        if troop.formation == 1
          if @num_single_troop_units >= @max_single_troop_units
            true
          else
            @num_single_troop_units += 1
            false
          end
        else
          super
        end
      end

      def recycle_troop? troop
        ['Pathfinders', 'Captain', 'Champion'].include? troop.name 
      end
    end

    class Orcs < ArmyDrafter
      def initialize(points, strategy, seed_units = nil)
        super 'Orcs', points, strategy, 
          (seed_units = seed_units || [ %w(Orcs-29), %w(Orcs-30) ]) # Kobolds
      end

      #def is_adding_troop_to_unit_smart?(unit, troop)
      #  if unit.troops.find {|t| t.name == 'Kobolds'}
      #    puts "Unit contains kobolds!" if @debug
      #    # Kobolds = canon fodder for troops that otherwise don't
      #    # get to have fodder.
      #    (@troops.empty?) or ((troop.formation == 1) and 
      #              (troop.is_engagement_troop? or troop.is_shooting_troop?))
      #  else
      #    super unit, troop
      #  end
      #end

      def recycle_troop? troop
        troop.name == 'Standard Bearer'
      end
    end

    class Macedonians < ArmyDrafter
      def initialize(points, strategy, seed_units = nil)
        super 'Macedonians', points, strategy, seed_units
      end

      def recycle_troop? troop
        ['Standard Bearer', 'Chiliarch', 'Alexandros', 'Agema'].include? troop.name
      end
    end

    class Persians < ArmyDrafter
      def initialize(points, strategy, seed_units = nil)
        super 'Persians', points, strategy, seed_units
      end

      def recycle_troop? troop
        ['Standard Bearer', 'Darius'].include? troop.name
      end
    end
  end
end

