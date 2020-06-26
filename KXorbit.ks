// Pre Launch Checks
SAS off.
Lock Throttle to 0.
RCS off.

clearscreen.
PRINT "Counting down:".
FROM {local countdown is 10.} UNTIL countdown = 0 STEP {SET countdown to countdown - 1.} DO {
    PRINT "..." + countdown.
    WAIT 1. 
}

print "Blast OFF !!!".

Function main {
  doLaunch().
  doAscent().
  until apoapsis > 100000 {
    doAutoStage().
  }
  doShutdown().
  doCircularization().
  print "Yer Boi, Space!".
  wait until false.
}

Function doCircularization {
  local circ is list(time:seconds + 30, 0).
  set circ to improveConverge(circ, protectFromPast(eccentricityScore@)).
  executeManeuver(list(circ[0],0, 0, circ[1])).
}

Function protectFromPast {
  parameter originalFunction.
  local replacementFunction is {
  parameter data.
  if data[0] < time:seconds + 15 {
    return 2^64.
  } else {
    return originalFunction(data).
  }
}.
return replacementFunction@.
}

Function eccentricityScore {
    parameter data.
    local mnv is node(time:seconds + eta:apoapsis, 0, 0, data[0]).
    addManeuverToFlightPlan(mnv).
    local result is mnv:orbit:eccentricity. 
    removeManeuverFromFlightPlan(mnv).
    return result.
}

Function improveConverge {
  parameter  data, scoreFunction.
  for stepSize in list(100,10,1) {
    until false {
      local oldScore is scoreFunction(data).
      set data to improve(data, stepSize, scoreFunction).
      if oldScore <= scoreFunction(data) {
        break.
      }
    }
  }
  return data.
}

Function improve {
    parameter data, stepSize, scoreFunction.
    local scoreToBeat is scoreFunction(data).
    local bestCandidate is data.
    local candidates is list().
    local index is 0.
    until index >= data:lengh {
      local incCandiate is data:copy().
      local decCandiate is data:copy().
      set inCandiate[index] to incCandiate[index] + stepSize. 
      set decCandiate[index] to decCandiate[index] - stepSize. 
      candiates:add(incCandiates).
      candiates:add(decCandiates).
      set index to index +1. 
}
  for candidate in candiates {
  local candiateScore is scoreFunction(candiate).
  if candiateScore < scoreToBeat {
    set scoreToBeat to candiateScore.
    set bestCandidate to candidate.
    }
  }
  return bestCandidate.
}

Function executeManeuver {
    parameter mList.
    local mnv is node(mList[0], mList[1], mList[2], mList[3]).
    addManeuverToFlightPlan(mnv).
    local startTime is calculateStartTime(mnv).
    wait Until time:seconds > startTime -10.
    lockSteeringAtManeuverTartget(mnv).
    wait until time:seconds > startTime.
    Lock throttle to 1.
    until isManeuverComplete(mnv) {
      doAutoStage().
    }
    lock throttle to 0.
    unlock steering. 
    removeManeuverFromFlightPlan(mnv).
}

Function addManeuverToFlightPlan {
    parameter mnv.
    add mnv.
}

function calulateStartTime {
    parameter mnv.
    return time:seconds + mnv:eta - maneuverBurnTime(mnv) / 2.
}

Function maneuverBurnTime {
    parameter mnv.
    local dv is mnv:deltaV:mag.
    local g0 is 9.80665.
    local isp is 0.

    list engines in myEngines. 
    for en in myEngines {
        if en:ignition and not en:flameout {
            set isp to isp + (en:isp * (en:availablethrust / ship:availablethrust)).
        }
    }

    local mf is ship:mass / constant():e^(dv / (isp * g0)).
    Local FuelFlow is ship:availablethrust / (isp * g0).
    local t is (ship:mass - mf) / fuelFlow.

    return t.
}

Function lockSteeringAtManeuverTartget {
    parameter mnv.
    lock steering to mnv:burnvector.
    
}

Function isManeuverComplete {
  parameter mnv.
  if not(defined originalVector) or originalVector = -1 {
    declare global originalVector to mnv:burnvector.
  }
  if vang(originalVector, mnv:burnvector) > 90 {
    declare global originalVector to -1.
    return true.
  }
  return false.
}

Function removeManeuverFromFlightPlan {
    parameter mnv.
    remove mnv.
}

Function doLaunch{
    LOCK throttle to 1.
    doSafeStage(). 
}

Function doAscent {
    lock targetPitch to 88.963 - 1.03287 * alt:radar^0.409511.
    set targetDirection to 90.
    lock steering to heading(targetDirection, targetPitch).
}

Function doAutoStage {
  if not(defined oldThrust) {
    global oldThrust is ship:availablethrust.
  }
  if ship:availablethrust < (oldThrust - 10) {
    until false {
      doSafeStage(). wait 1.
      if ship:availablethrust > 0 {
        break.
      }
    }
    global oldThrust is ship:availablethrust.
  }
}

Function doShutdown {
    lock throttle to 0.
    lock steering to prograde.
}

Function doSafeStage {
  wait until stage:ready.
  stage.
}

main().