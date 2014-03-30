#!/usr/bin/ruby
$LOAD_PATH << './lib'

require 'cgi'
require 'pocket-battles'

DEFAULT_POINTS = 50
VALID_POINTS = [20, 30, 40, 50, 60, 70, 80, 90, 100]

#-- DISPLAY --

def faction_select(num)
  s = %Q(<select name="faction#{num}">\n<option value="">-</option>)
  PocketBattles.get_all_faction_names.sort.each do |name|
    s += %Q(<option value="#{name}" #{(eval("@faction#{num}") == name) ? 'selected' : ''}>#{name}</option>)
  end
  s += '</select>'
end

def points_select
  s = %Q(<select name="points">\n)
  VALID_POINTS.each do |p|
    s += %Q(<option value="#{p}"} #{(@points == p) ? 'selected' : ''}>#{p}</option>)
  end
  s += '</select>'
end

def display_army(army)
  if army 
    s = %Q(<p>#{army.size} units [#{army.troops.size} troop tiles], #{army.points} points</p>)
    s += "<ol>\n"

    army.units.sort.each do |unit|
      s += '<li>' 
      s += (unit.troops.sort.map { |troop| 
                  s = "<tt>#{troop.reference}</tt> #{troop.name} <br /><div style='padding-left: 3ex; margin: 0; font-size: 90%; line-height: 1.25em;'>"
                  s += " Engage: #{troop.engagement.join('-')}" unless troop.engagement.empty?
                  s += " Shoot: #{troop.shooting.join('-')}" unless troop.shooting.empty?
                  s += "<br />"
                  s += " Points: #{troop.points} Formation: #{troop.formation} Wounds: #{troop.wounds}"
                  s += "<br />Powers: #{troop.powers.join(', ')}" unless troop.powers.empty? 
                  s += "</div>" }).join("\n")
      s += '</li>'
    end
    s += "\n</ol>"
  else
    ''
  end
end

def display_powers(army)
  if army
  s = '<p><strong>Powers:</strong></p><ul>'
  s += (army.powers.map { |p| "<li><strong>#{p}:</strong> #{PocketBattles.get_power_description(p)}</li>" }).join(' ')
  s += '</ul>'
  else
  ''
  end
end

def display_errors
  s = ''
  unless @errors.empty? 
    s = %Q(<div class="error"><p><strong>Errors have occurred!</strong></p>)
    @errors.each do |e|
      s += %Q(<pre>#{CGI.escapeHTML(e.to_s)}</pre>)
    end
    s += '</div>'
  end
  return s
end

#-- DATA -- 

def get_points
  if @cgi.has_key?('points')
    points = @cgi['points'].to_i
    if points < 0 
      points = VALID_POINTS[0]
    elsif !(VALID_POINTS.member? points)
      points = DEFAULT_POINTS
    end
  else
    points = DEFAULT_POINTS
  end
  return points
end

def get_faction(num)
  faction = @cgi["faction#{num}"]
  if PocketBattles.is_faction? faction
    faction.untaint
  elsif (faction == nil) || (faction.empty?)
    faction = nil
  else
    @errors << "Unknown Faction #{num} #{CGI.escapeHTML(faction)}"
    faction = nil
  end
  return faction
end

#-- MAIN --

@cgi = CGI.new
@errors = []

@points = get_points
@faction1 = get_faction 1
@faction2 = get_faction 2

@army1 = nil
@army2 = nil
if @faction1
  @army1 = PocketBattles::Draft.draft_for(@faction1, @points, 'Compatible')
end
if @faction2
  @army2 = PocketBattles::Draft.draft_for(@faction2, @points, 'Compatible')
end

@cgi.out { 
  <<-END
<html>
  <head>
  <title>Pocket Battlelizer</title>
  <meta name="viewport" content="width=320,initial-scale=1.0,user-scalable=false" />
  <style type="text/css">
    body { width: 320px; padding: 5px; margin: 0px; }
    table { width: 100%; margin: 0px; }
    th, td { text-align: left; vertical-align: top; padding: 4px; }
    th { font-weight: normal; }
    label { font-weight: bold; }
    ol li { border: 1px dotted #cccccc; padding: 5px; margin: 5px 0 5px 0; }
    div.error { 
    text-align: center; 
    margin: 1ex auto 1ex auto; 
    border: 2px solid red; 
    background-color: pink;
    width: 80%; 
    }
  </style>
  </head>
  <body>
  #{display_errors}

  <form method="get">
    <table>
    <tr>
      <th><label>Faction #1:</label></th>
      <td>#{faction_select 1}</td>
    </tr>
    <tr>
      <th><label>Faction #2:</label></th>
      <td>#{faction_select 2}</td>
    </tr>
    <tr>
      <th><label>Points:</label></th>
      <td>#{points_select}</td>
    </tr>
    <tr>
      <td colspan="2"><input type="submit" value="Battlelize" /></td>
    </tr>
    </table>
  </form>

  #{display_army @army1}
  #{display_powers @army1}
  
  #{display_army @army2}
  #{display_powers @army2}
  
  </body>
</html>
  END
}
