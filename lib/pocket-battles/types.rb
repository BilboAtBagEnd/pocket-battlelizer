require 'yaml'
# 
# Base classes for PocketBattles objects: 
#
#  Troop - individiual pieces/tiles
#  Faction - "sides" that a troop is on, like Celts or Orcs
#  Unit - troops together as they would be in an army
#  Army - made of units 
#
module PocketBattles
  FACTION_LIB = 'faction-data'
  FACTIONS = {}

  def PocketBattles.get_all_factions
    FACTIONS.values.sort { |a,b| a.name <=> b.name }
  end

  def PocketBattles.get_all_faction_names
    FACTIONS.keys.sort
  end

  def PocketBattles.has_faction?(faction_name)
    FACTIONS.has_key? faction_name
  end

  def PocketBattles.get_faction(faction_name) 
    FACTIONS[faction_name]
  end

  def PocketBattles.is_faction?(faction_name)
    FACTIONS.has_key? faction_name
  end

  # 
  # Fields
  #   name - name of the troop
  #   number - number of the troop tile in its faction (an integer)
  #   engagement - array of digit strings indicating engagement dice
  #   shooting - array of digit strings indicating shooting dice
  #   points - deployment points
  #   formation - formation points aka formation value
  #   wounds - number of wounds 
  #   powers - array of string power names
  #   faction - Faction object this troop belongs to.
  #
  class Troop 
    include Comparable

    # Close engagement combat powers only compatible with shooting units
    SHOOTING_POWERS_REGEX = /(\+\d Shooting)|(Wide Arc)|(Long Range)|Auxiliary|(First Strike)|Skirmish|(\+\d Wounds)/i
    # Close shooting combat powers only compatible with engagement units
    ENGAGEMENT_POWERS_REGEX = /(\+\d Engagement)|Overwhelming|Impetus|Fury|Flying|Scout|Auxiliary|(First Strike)|Skirmish|(\+\d Wounds)/i
    # Support troop powers
    SUPPORT_POWERS_REGEX = /Excite|Leader|(Double Order)|Heal|Control|Galvanize|Prestige|Sacrifice|Tough/i

    attr_reader :name, :number, :engagement, :shooting, 
          :points, :formation, :wounds, :powers, :faction

    # Constructor.
    #   faction - Faction object this troop is part of
    #   number  - faction-local id of the troop tile as an integer 
    #   data  - structure as read from the YAML 
    def initialize(faction, number, data)
      @faction = faction
      @name = data['name']
      @number = number.to_i
      
      # Required data
      @points = data['points'].to_i if data.has_key? 'points'
      if data.has_key? 'formation'
        @formation = data['formation']
        unless @formation == '*'
          @formation = @formation.to_i
        end
      end

      # Optional data
      @shooting = (data['shooting'].to_s.split('-') if data.has_key? 'shooting') || []
      @engagement = (data['engagement'].to_s.split('-') if data.has_key? 'engagement') || []
      @powers = (data['powers'].to_a if data.has_key? 'powers') || []
      @wounds = (data['wounds'].to_i if data.has_key? 'wounds') || 0
    end

    # Fancier troop id, globalized across all factions.
    def reference
      "#{@faction.name}-#{'%02d' % @number}"
    end

    # Only used by Faction when reading from YAML; some troops are only 
    # partly specified, depending on the full definition of other, similar troops 
    # with the same names for full information. 
    def has_all_info?
      @points != nil
    end

    # Only used by Faction when reading from YAML; see has_all_info? 
    # This fills out the rest of the information from the given template troop. 
    def fill_from_troop(troop)
      @points = troop.points 
      @formation = troop.formation
      @wounds = troop.wounds
      @powers = troop.powers.clone
    end

    def has_power?(power)
      @powers.include? power
    end

    # The Auxiliary power is special enough to need its own method, since 
    # it breaks the most basic rule of unit building 
    # (e.g. total number of troop tiles <= min formation value)
    def is_aux_troop?
      @powers.include? 'Auxiliary'
    end

    # Whether this troop needs to be part of a combat unit.
    def is_combat_troop?
      is_shooting_troop? or 
      is_engagement_troop? or 
      has_shooting_compatible_powers? or
      has_engagement_compatible_powers?
    end

    # Whether this troop is only a support troop.
    def is_support_troop?
      (not is_combat_troop?) and ((@powers.find {|p| p =~ SUPPORT_POWERS_REGEX}) != nil)
    end

    def is_fighting_troop?
      is_shooting_troop? or is_engagement_troop?
    end

    # Whether this troop can shoot by itself
    def is_shooting_troop?
      not @shooting.empty?
    end

    # Whether this troop can engage by itself
    def is_engagement_troop?
      not @engagement.empty?
    end

    # Whether this troop boosts its unit's shooting with a special power
    def has_shooting_compatible_powers?
      (@powers.find {|p| (p =~ SHOOTING_POWERS_REGEX)}) != nil
    end

    # Whether this troop boosts its unit's engagement with a special power
    def has_engagement_compatible_powers?
      (@powers.find {|p| (p =~ ENGAGEMENT_POWERS_REGEX)}) != nil
    end

    def is_compatible_with_troop?(troop)
      if troop.is_aux_troop? or self.is_aux_troop?
        true
      elsif troop.formation <= 1 || self.formation <= 1
        false
      elsif (troop.is_shooting_troop? && self.is_shooting_troop?) ||
          (troop.is_shooting_troop? && self.has_shooting_compatible_powers?) || 
          (troop.has_shooting_compatible_powers? && self.is_shooting_troop?)
        true
      elsif (troop.is_engagement_troop? && self.is_engagement_troop?) || 
          (troop.is_engagement_troop? && self.has_engagement_compatible_powers?) || 
          (troop.has_engagement_compatible_powers? && self.is_engagement_troop?)
        true
      else
        false
      end
    end

    def to_s
      s = "#{@name} #{self.reference}, "
      s += "s#{@shooting.join('-')}, " unless @shooting.empty?
      s += "e#{@engagement.join('-')}, " unless @engagement.empty?
      s += "(#{@points})[#{@formation}] !#{@wounds}!"
      s += " {#{@powers.join(', ')}}" unless @powers.empty?
      s
    end

    def <=>(other)
      @number <=> other.number
    end
  end

  #
  # Fields:
  #  troops - array of Troop objects, in numerical order
  #  name - name of this faction (like Celts, Romans, etc)
  #
  class Faction
    attr_reader :troops, :name

    def initialize(name, data)
      @name = name
      @troops = []
      @troops_by_ref = {}
      reference_troops = {}

      data.keys.sort.each do |key|
        value = data[key]
        troop = Troop.new(self, key, value)
        if troop.has_all_info? 
          reference_troops[troop.name] = troop
        else
          troop.fill_from_troop(reference_troops[troop.name])
        end
        @troops << troop
        @troops_by_ref[troop.reference] = troop
      end
    end

    # Return a troop by its given number
    def troop_by_id(n)
      n = n.to_i
      raise "Id #{n} larger than faction size #{@troops.size}" if n > @troops.size 
      @troops[n - 1]
    end

    # Return a troop by its reference
    def troop_by_ref(ref)
      raise "Can't find troop #{ref}" unless @troops_by_ref.has_key? ref
      @troops_by_ref[ref]
    end

    # Return the smallest deployment point value of any troop in this faction.
    def min_troop_points
      @troops.min { |a,b| a.points <=> b.points }
    end

    def to_s
      "<Faction #{@name}>"
    end
  end

  #
  # Fields:
  #  troops - array of Troop objects part of this unit
  #
  class Unit 

    include Comparable

    attr_reader :troops

    def initialize(troops = [])
      @troops = troops.clone
    end

    # whether adding the given troop would violation unit build rules.
    def can_add_troop?(troop)
      # we can always add an auxiliary troop if there's no other aux troop
      if troop.is_aux_troop? 
        return (not has_aux_troop?)
      end

      min_formation_points_of_both = 
        self.min_formation_points < troop.formation ? self.min_formation_points : troop.formation

      new_size = self.ignore_aux_troops.size + 1
      if (new_size == min_formation_points_of_both) 
        # We're going to fill up this unit, better make sure 
        # last chance attributes, like > 0 wounds, can be fulfilled 
        # with this last troop.
        return false if (self.wounds + troop.wounds) < 1
      end

      # Otherwise, must be able to fit into this formation value
      new_size <= min_formation_points_of_both
    end

    # Add a troop. Does no checking.
    def add_troop(troop)
      @troops << troop
    end

    # whether some troop in this unit is compatible with the given troop
    def is_compatible_with_troop? troop
      (@troops.find {|t| t.is_compatible_with_troop? troop}) != nil
    end

    # whether this unit has fighting dice at all
    def is_fighting_unit?
      (@troops.find {|t| t.is_fighting_troop? }) != nil
    end

    # whether this unit can shoot by itself
    def is_shooting_unit?
      (@troops.find {|t| t.is_shooting_troop? }) != nil
    end

    # whether this unit can engage by itself
    def is_engagement_unit?
      (@troops.find {|t| t.is_engagement_troop? }) != nil
    end

    # whether this unit has an auxiliary troop
    def has_aux_troop? 
      (@troops.find {|t| t.is_aux_troop?}) != nil
    end

    # number of troops
    def size
      @troops.size
    end

    # whether this has any troops
    def empty?
      @troops.empty?
    end

    # total number of wounds across troops
    def wounds
      @troops.inject(0) {|memo, t| t.wounds + memo}
    end

    # total number of points across troops
    def points
      @troops.inject(0) {|memo, t| t.points + memo}
    end

    # all powers used by by the troops
    def powers
      all_powers_dupes = @troops.inject([]) { |memo, t| memo += t.powers }
      all_powers_dupes.sort.uniq
    end

    # unit's non-auxiliary troops
    def ignore_aux_troops
      @troops.reject {|t| t.is_aux_troop?}
    end

    # minimum formation value amongst troops 
    def min_formation_points
      troop_with_min_formation = self.ignore_aux_troops.min {|a,b| a.formation <=> b.formation}
      if troop_with_min_formation
        troop_with_min_formation.formation
      else
        100 # assumed max formation
      end
    end

    # true if non-aux troops can no longer be added
    def is_full?
      self.ignore_aux_troops.size >= self.min_formation_points
    end

    # engagement dice across all troops
    def engagement_dice
      @troops.inject([]) {|memo, t| memo + t.engagement}
    end

    # shooting dice across all troops
    def shooting_dice
      @troops.inject([]) {|memo, t| memo + t.shooting}
    end

    # powers across all troops
    def powers
      @troops.inject([]) {|memo, t| memo + t.powers}
    end

    def to_s
      "<Unit #{self.is_full? ? 'full' : ''} [#{self.min_formation_points}], troops = [#{((@troops.sort {|a,b| a.reference <=> b.reference}).map { |t| t.to_s }).join(', ')}]>"
    end

    # raise exceptions if something is wrong with this unit
    def validate
      raise "#{self} has no wounds!" if self.wounds <= 0
      raise "#{self} has >1 auxiliary troop!" if (@troops.select {|t| t.is_aux_troop?}).size > 1
      raise "#{self} has more troops than formation value!" if self.ignore_aux_troops.size > self.min_formation_points
    end

    def <=>(other)
      (@troops.min) <=> (other.troops.min)
    end
  end

  #
  # Fields
  #   units - Unit objects in this army
  #
  class Army
    attr_reader :units

    def initialize(units = [])
      @units = units.clone
    end

    # Adds a unit; will not add an empty unit, but otherwise
    # does no additional checking.
    def add_unit(unit)
      raise "Can't add empty unit #{unit}!" if unit.empty?
      @units << unit
    end

    # number of units
    def size
      @units.size
    end

    # whether there are any units
    def empty?
      @units.empty?
    end

    # return an array of troops consolidated across all units
    def troops
      @units.inject([]) {|memo, u| memo + u.troops}
    end

    # return total deployment points across all units
    def points
      @units.inject(0) { |memo, u| memo + u.points }
    end

    # return all powers used by the units
    def powers
      all_powers_dupes = @units.inject([]) { |memo, u| memo += u.powers }
      all_powers_dupes.sort.uniq
    end

    def to_s
      "<Army #{self.size} units, #{self.points} points, \n - #{((@units.sort {|a,b| a.troops[0].reference <=> b.troops[0].reference}).map { |u| u.to_s }).join("\n - ")}\n>"
    end

    def to_summary(longer = false)
      s = "Army #{self.size} units, #{self.points} points,\n"
      (@units.sort {|a,b| (a.troops.sort {|c,d| c.reference <=> d.reference})[0].reference <=> (b.troops.sort {|c,d| c.reference <=> d.reference})[0].reference}).each do |u|
        s += ' - ' 
        s += ((u.troops.sort {|a,b| a.reference <=> b.reference}).map { |t| "(#{t.reference}) #{t.name}" }).join(', ')
        if longer
          s += ": (#{u.points})[#{u.min_formation_points}]!#{u.wounds}!"
          s += " s#{u.shooting_dice.sort.join('-')}" unless u.shooting_dice.empty?
          s += " e#{u.engagement_dice.sort.join('-')}" unless u.engagement_dice.empty?
          s += " {#{u.powers.sort.join(', ')}}" unless u.powers.empty? 
        end
        s += "\n"
      end
      s
    end

    # raise errors if something is wrong with the army
    def validate
      @units.each {|u| u.validate}
    end
  end

  # Initialize all armies
  Dir.glob("#{FACTION_LIB}/*.yaml").each do |file|
    begin 
      m = file.match('([-A-Za-z0-9]+)\.yaml$')
      faction_name = m[1]
      faction_data = YAML.load_file(file)
      faction_data.keys.each do |key|
        unless key.class == Integer
          value = faction_data.delete key
          faction_data[key.to_i] = value
        end
      end

      FACTIONS[faction_name] = Faction.new(faction_name, faction_data)
    rescue => e
      raise "Couldn't parse #{file}: #{e}"
    end
  end
end
