import KsApi

/**
 Determines if the personalization data in the project implies that the current user is backing the
 reward passed in. Because of the many ways in which we can get this data we have multiple ways of
 determining this.

 - parameter reward:  A reward.
 - parameter project: A project.

 - returns: A boolean.
 */
internal func userIsBacking(reward reward: Reward, inProject project: Project) -> Bool {
  guard let backing = project.personalization.backing else { return false }

  return backing.reward?.id == reward.id
    || backing.rewardId == reward.id
    || (backing.reward == nil && backing.rewardId == nil && reward == Reward.noReward)
}

/**
 Computes the pledge context (i.e. new pledge, managing reward, changing reward) from a project and reward.

 - parameter project: A project.
 - parameter reward:  A reward.

 - returns: A pledge context.
 */
internal func pledgeContext(forProject project: Project, reward: Reward) -> Koala.PledgeContext {
  if project.personalization.isBacking == .Some(true) {
    return userIsBacking(reward: reward, inProject: project) ? .manageReward : .changeReward
  }
  return .newPledge
}

/**
 Computes the minimum and maximum amounts that can be pledge to a reward. For the "no reward" reward,
 this looks up values in the table of launched countries, since the values depend on the currency.

 - parameter project: A project.
 - parameter reward:  A reward.

 - returns: A pair of the minimum and maximum amount that can be pledged to a reward.
 */
internal func minAndMaxPledgeAmount(forProject project: Project, reward: Reward?) -> (min: Int, max: Int) {

  // The country on the project cannot be trusted to have the min/max values, so first try looking
  // up the country in our launched countries array that we get back from the server config.
  let country = AppEnvironment.current.launchedCountries.countries
    .filter { $0 == project.country }
    .first
    .coalesceWith(project.country)

  switch reward {
  case .None, .Some(Reward.noReward):
    return (country.minPledge ?? 1, country.maxPledge ?? 10_000)
  case let .Some(reward):
    return (reward.minimum, country.maxPledge ?? 10_000)
  }
}

/**
 Computes the minimum amount needed to pledge to a reward. For the "no reward" reward,
 this looks up values in the table of launched countries, since the values depend on the currency.

 - parameter project: A project.
 - parameter reward:  A reward.

 - returns: The minimum amount needed to pledge to the reward.
 */
internal func minPledgeAmount(forProject project: Project, reward: Reward?) -> Int {

  return minAndMaxPledgeAmount(forProject: project, reward: reward).min
}
