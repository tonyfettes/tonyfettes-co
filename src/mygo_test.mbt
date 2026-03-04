///|
test "yield_ and resume_" {
  let values = []
  let co = @mygo.Routine::new(co => {
    values.push(1)
    co.yield_()
    values.push(2)
  })
  values.push(3)
  co.resume_()
  values.push(4)
  assert_eq(values, [1, 3, 2, 4])
}

///|
test "Round-robin" {
  let tasks = Array::makei(4, id => {
    @mygo.Routine::new(co => {
      for i = 0; i < 3; i = i + 1 {
        println("  [task \{id}] step \{i}")
        co.yield_()
      }
      println("  [task \{id}] finished")
    })
  })
  let round = for round = 0; ; round = round + 1 {
    println("[scheduler] --- round \{round} ---")
    let mut done = true
    for task in tasks {
      if !task.stopped() {
        task.resume_()
        done = false
      }
    }
    if done {
      break round
    }
  } nobreak {
    round
  }
  println("[scheduler] All tasks completed after \{round} rounds")
}
