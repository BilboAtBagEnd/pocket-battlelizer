require 'yaml'

module PocketBattles
    ARMY_LIB = 'army-data'
    ARMIES = {}

    def self.armies
        ARMIES.keys.sort
    end

    def self.has_army?(army)
        ARMIES.has_key? army
    end

    def self.army(army) 
        ARMIES[army]
    end

    class Unit 
        attr_reader :name, :number, :engagement, :shooting, :points, :formation, :wounds, :powers, :army
        def initialize(army, number, data)
            @army = army
            @name = data['name']
            @number = number.to_i

            @shooting = data['shooting'].to_s if data.has_key? 'shooting'
            @engagement = data['engagement'].to_s if data.has_key? 'engagement'
            @points = data['points'].to_i if data.has_key? 'points'
            @formation = data['formation'].to_i if data.has_key? 'formation'
            @wounds = data['wounds'].to_i if data.has_key? 'wounds'
            @powers = data['powers'].to_a if data.has_key? 'powers'
        end

        def reference
            "#{@army.name}-#{'%02d' % @number}"
        end

        def has_all_info?
            @points != nil
        end

        def fill_from_unit(unit)
            @points = unit.points
            @formation = unit.formation
            @wounds = unit.wounds
            @powers = unit.powers
        end

        def to_s
            "{#{@name} #{self.reference}, engagement_dice = #{@engagement.inspect}, shooting_dice = #{@shooting.inspect}, points = #{@points.inspect}, formation = #{@formation.inspect}, wounds = #{@wounds.inspect}, powers = #{@powers.inspect}}"
        end
    end

    class Army
        attr_reader :name, :units

        def initialize(name, data)
            @name = name
            @units = {}
            reference_units = {}

            data.keys.sort.each do |key|
                value = data[key]
                unit = Unit.new(self, key, value)
                if unit.has_all_info? 
                    reference_units[unit.name] = unit
                else
                    unit.fill_from_unit(reference_units[unit.name])
                end
                @units[key] = unit
            end
        end

        def unit(n)
            key = n.to_i
            if @units.has_key? key
                @units[key]
            else
                raise "Couldn't find unit with number #{n}"
            end
        end
    end

    # Initialize all armies
    Dir.glob("#{ARMY_LIB}/*.yaml").each do |file|
        begin 
            m = file.match('([-A-Za-z0-9]+)\.yaml$')
            army_name = m[1]
            army_data = YAML.load_file(file)
            army_data.keys.each do |key|
                unless key.class == Integer
                    value = army_data.delete key
                    army_data[key.to_i] = value
                end
            end

            ARMIES[army_name] = Army.new(army_name, army_data)
        rescue => e
            raise "Couldn't parse #{file}"
        end
    end
end
