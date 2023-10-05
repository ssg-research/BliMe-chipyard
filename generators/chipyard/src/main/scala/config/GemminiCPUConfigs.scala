package chipyard

import boom.common._
import freechips.rocketchip.subsystem._

object CustomGemmminiCPUConfigs {
  // Default CPU configs
  type RocketBigCores = WithNBigCores
  type RocketMedCores = WithNMedCores
  type RocketSmallCores = WithNSmallCores

  type BoomLargeCores = WithNLargeBooms
  type BoomMedCores = WithNMediumBooms
  type BoomSmallCores = WithNMediumBooms

  type BlindedBoom = WithNLarge8Booms

  // Specify which CPU configs you want to build here
  type CustomCPU = BlindedBoom
}
