#
# Purely informational enums, mapping from names to descriptions.
#
module PocketBattles
  POWERS = {
    'Control' => 'Issue an order to this Unit to perform an Action with another of your Units, without spending orders on it.',
    'Double Order' => 'NOT ON FIRST TURN: Issue an order to this Unit to issue orders to other 2 friendly Units in the same turn, spending Order tokens as usual. Resolve the issued orders one after the other.', 
    'Excite' => 'NOT ON FIRST TURN: When issuing an order of "Charge", "Carry on Engagement", or "Shoot" to one of your Units, also issue an order to this Unit to get 1 further die in engagement or shooting.',
    'Galvanize' => 'When issuing an order of "Charge" to one of your Units, also issue an order to this Unit to give the charging unit the Overwhelming Trait.',
    'Heal' => 'NOT ON FIRST TURN: Issue an order to this Unit to recover 1 Wound Token from any 1 other friendly Unit. The recovered Order Token becomes immediately available.',

    'Auxiliary' => 'Up to one troop with this trait can be added to any other Unit, regardless of Formation Value limits.',
    'Blood Lust' => 'When you roll to hit with a Unit with this trait, roll from 1 to 6 dice, with no other bonuses. Each 1 is a wound inflicted on the attacking Unit itself. If the Unit itself is not destroyed, inflict wounds as normal.',
    'Disband' => 'When this Unit successfully hits in Engagement or Shooting - but doesn\' destroy the enemy Unit - the Opponent must place apart one of his  unused Order Tokens, if he has any, as it was spent.',
    '+X Engagement' => 'When involved in an Engagement, this Unit rolls +X additional dice.',
    'Fast' => 'This Unit can be issued an order to perform an Action also if it performed a Unit Redployment in the first phase of its turn.',
    'First Strike' => 'If this Unit is charged, it can roll to hit before the charging Unit.',
    'Flying' => 'This Unit can charge a Unit in the enemy Rear Zone. It can be intercepted or shot at as normal, by a Unit in the Front Zone.',
    'Fury' => 'This Unit rolls one additional die in Engagement for each Order Token (not Wound) present on it.',
    'Impetus' => 'When this Unit is issued a Charge order, roll 2 additional dice for engagement due to the Charge, instead of just 1.',
    'Leader' => 'If this Unit is present on the Battlefield, the owner has 1 more Order Token available. Return the Order Token when the Unit is destroyed.',
    'Long Range' => 'This Unit can shoot from the Rear of a Sector. This trait cannot be used for "Shooting against" a Charging Unit.',
    'Overwhelming' => 'When this Unit is issued a Charge order and destroys the enemy Unit, in the same turn it must immediately Charge another eligible enemy Unit, without spending further Order Tokens.',
    'Prestige' => 'If this Unit is present on the battlefield, add its Deployment points to the total of destroyed enemy troops when calculating the victory conditions.',
    'Reactive' => 'Issuing an order to this Unit costs the same amount of Order Tokens present on it (instead of 1 more Order Token). The first order costs 1 Order Token, as always.',
    'Regenerate' => 'Recover all the Wound Tokens (turning them into Orders) from a Unit with this trait at the end of each Battle Round.',
    '+X Shooting' => 'When shooting, this Unit rolls +X additional dice.',
    'Sacrifice' => 'If this Unit is hit, you can destroy the Troop with "Sacrifice", not placing any Wound token on the other Troops.',
    'Scout' => 'This Unit can charge a Unit in the enemy Front Zone without being intercepted or shot against.',
    'Skirmish' => 'This Unit can intercept or shoot against an enemy Unit without spending any order tokens on it.',
    'Slow' => 'This Unit cannot perform a Unit Redeployment',
    'Tough' => 'If this Unit is hit, you can force the opponent Unit to roll again a single die that resulted in a hit.',
    'Wide Arc' => 'This Unit can shoot on the Front or Engagement Zone of an adjacent Sector.',
    '+X Wounds' => 'If this Unit scores at least 1 hit in Engagement or Shooting, it scores an additional +X Wounds.',
    
  }

  def self.normalize_power(power)
    power.sub(/\+\d/, '+X')
  end

  def self.get_power_description(power)
    POWERS[normalize_power(power)]
  end
end
