// 現在の merge / release ゲートの有限模型。
// 通常経路 (Merge) と、管理者が必須CIを迂回できる経路 (AdminMerge) を分ける。
module MergeGate {
  var prOpen: bool
  var checksPassed: bool
  var baseCurrent: bool
  var merged: bool
  var cleanMerge: bool
  var tagged: bool
  var released: bool

  action init = all {
    prOpen' = false,
    checksPassed' = false,
    baseCurrent' = true,
    merged' = false,
    cleanMerge' = false,
    tagged' = false,
    released' = false,
  }

  action OpenPR = all {
    not(prOpen), not(merged),
    prOpen' = true,
    checksPassed' = checksPassed,
    baseCurrent' = baseCurrent,
    merged' = merged,
    cleanMerge' = cleanMerge,
    tagged' = tagged,
    released' = released,
  }

  // 必須CI (actionlint / validate / test-go) が現在のbaseに対して成功する。
  action ChecksPass = all {
    prOpen, not(merged),
    prOpen' = prOpen,
    checksPassed' = true,
    baseCurrent' = true,
    merged' = merged,
    cleanMerge' = cleanMerge,
    tagged' = tagged,
    released' = released,
  }

  // baseが前進すると、直前の検査は現在のbaseに対応しなくなる。
  action BaseMoves = all {
    prOpen, not(merged), baseCurrent, checksPassed,
    prOpen' = prOpen,
    checksPassed' = false,
    baseCurrent' = false,
    merged' = merged,
    cleanMerge' = cleanMerge,
    tagged' = tagged,
    released' = released,
  }

  // 通常のmerge。必須CIとbase一致を確認済みのときだけ進める。
  action Merge = all {
    prOpen, not(merged), checksPassed, baseCurrent,
    prOpen' = prOpen,
    checksPassed' = checksPassed,
    baseCurrent' = baseCurrent,
    merged' = true,
    cleanMerge' = true,
    tagged' = tagged,
    released' = released,
  }

  // 管理者が必須CIを迂回してmergeする。branch protectionのenforce_admins=falseに対応する。
  action AdminMerge = all {
    prOpen, not(merged),
    prOpen' = prOpen,
    checksPassed' = checksPassed,
    baseCurrent' = baseCurrent,
    merged' = true,
    cleanMerge' = false,
    tagged' = tagged,
    released' = released,
  }

  action Tag = all {
    merged, not(tagged),
    prOpen' = prOpen,
    checksPassed' = checksPassed,
    baseCurrent' = baseCurrent,
    merged' = merged,
    cleanMerge' = cleanMerge,
    tagged' = true,
    released' = released,
  }

  action Release = all {
    tagged, not(released),
    prOpen' = prOpen,
    checksPassed' = checksPassed,
    baseCurrent' = baseCurrent,
    merged' = merged,
    cleanMerge' = cleanMerge,
    tagged' = tagged,
    released' = true,
  }

  action step = any { OpenPR, ChecksPass, BaseMoves, Merge, AdminMerge, Tag, Release }

  // 必須CIを経ていないmergeを許さない。
  val CleanMerge = not(merged) or cleanMerge
  // mergeされていないcommitにtagを付けない。
  val NoTagWithoutMerge = not(tagged) or merged
  // 検査済みの通常経路でリリースまで到達できるかを見るための否定命題。
  val NotReleasedClean = not(released and cleanMerge)
}
