// Shim: o build UMD do tom-select não tem export default no import map.
// Importa tudo e reexporta o default para que os controllers funcionem.
import * as TomSelectModule from "tom-select"
const TomSelect = TomSelectModule.default ?? TomSelectModule
export default TomSelect
