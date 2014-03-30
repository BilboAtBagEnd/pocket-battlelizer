require 'yaml'

module PocketBattles
    ARMY_LIB = 'army-data'
    ARMIES = {}

    def self.armies
        ARMIES.values.sort { |a,b| a.name <=> b.name }
    end

    def self.army_names
        ARMIES.keys.sort
    end

    def self.has_army?(army)
        ARMIES.has_key? army
    end

    def self.army(army) 
        ARMIES[army]
    end

    class Unit 

        attr_reader :name, :number, :engagement, :shooting, 
                    :points, :formation, :wounds, :powers, :army

        def initialize(army, number, data)
            @army = army
            @name = data['name']
            @number = number.to_i
            
            # Required data
            @points = data['points'].to_i if data.has_key? 'points'
            @formation = data['formation'].to_i if data.has_key? 'formation'

            # Optional data
            @shooting = (data['shooting'].to_s if data.has_key? 'shooting') || ''
            @engagement = (data['engagement'].to_s if data.has_key? 'engagement') || ''
            @powers = (data['powers'].to_a if data.has_key? 'powers') || []
            @wounds = (data['wounds'].to_i if data.has_key? 'wounds') || 0
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
            @units = []
            @units_by_ref = {}
            reference_units = {}

            data.keys.sort.each do |key|
                value = data[key]
                unit = Unit.new(self, key, value)
                if unit.has_all_info? 
                    reference_units[unit.name] = unit
                else
                    unit.fill_from_unit(reference_units[unit.name])
                end
                @units << unit
                @units_by_ref[unit.reference] = unit
            end
        end

        def unit_by_id(n)
            n = n.to_i
            raise "Id #{n} larger than army size #{@units.size}" if n > @units.size 
            @units[n - 1]
        end

        def unit_by_ref(ref)
            raise "Can't find unit #{ref}" unless @units_by_ref.has_key? ref
            @units_by_ref[ref]
        end

        def min_unit_points
            @units.min { |a,b| a.points <=> b.points }
        end

        def to_s
            "[Army #{@name}]"
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
            raise "Couldn't parse #{file}: #{e}"
        end
    end
end
