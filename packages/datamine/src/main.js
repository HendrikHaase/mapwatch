/** PyPoE exports more data than Mapwatch needs. Filter some of it. */
const _ = require('lodash')
const schema = require('./schema/main.json')
const fs = require('fs').promises

fs.readdir('./dist/lang')
.catch(err => {
  console.error(err)
  process.exit(1)
})
.then(files => {
  const json = require('../dist/all.json')
  const lang = {}
  for (let file of files) {
    const key = file.replace('.json', '')
    lang[key] = require('../dist/lang/'+file)
  }
  main(json, lang)
})

function main(json, lang) {
  const out = transform(json, lang)
  console.log(JSON.stringify(out, null, 2))
  // console.log(JSON.stringify(out))
}
function transform(rawJson, rawLangs) {
  const json = _.keyBy(rawJson.map(file => {
    const header = file.header.map(h => h.name)
    const data = rowsToObjects(header, file.data)
    return {...file, header, data}
  }), 'filename')
  const langs = _.mapValues(rawLangs,
    l => _.keyBy(l.map(file => {
      const header = file.header.map(h => h.name)
      const data = rowsToObjects(header, file.data)
      return {...file, header, data}
    }), 'filename')
  )
  const uniqueMaps = json["UniqueMaps.dat"].data.map(n => transformUniqueMap(n, {json}))
  const atlasNodes = json["AtlasNode.dat"].data.map(n => transformAtlasNode(n, {json}))
  const worldAreas = json["WorldAreas.dat"].data.map((w, index) => transformWorldArea(w, {
    index,
    json,
    atlasNodes: _.keyBy(atlasNodes, 'WorldAreasKey'),
    uniqueMaps: _.keyBy(uniqueMaps, 'WorldAreasKey'),
  }))
  // I'm interested in maps, towns, and hideouts. other zones - usually campaign stuff - don't matter to mapwatch
  .filter(w => w.IsMapArea || w.IsUniqueMapArea || w.IsTown || w.IsHideout)
  // it looks like maps with no visuals are either duplicates or boss arenas. Either way, not interested
  .filter(w => w.ItemVisualIdentity || !w.IsMapArea)

  const ret = _.mapValues({
    worldAreas,
  }, sheetFromObjects)
  ret.lang = _.mapValues(langs, l => transformLang(l, {json, worldAreasById: _.keyBy(worldAreas, 'Id')}))
  return ret
  // }, _.identity)
}
function transformLang(raw, {worldAreasById}) {
  // areas all have different names for different languages, map id -> name.
  // mapwatch is usually more concerned with name -> id for log parsing, but it can deal.
  const worldAreas = raw["WorldAreas.dat"].data.filter(w => !!worldAreasById[w.Id])
  // "You have entered" text can vary based on the user's language, so import it too
  const backendErrors = raw["BackendErrors.dat"].data.filter(e => e.Id == 'EnteredArea')
  return {
    backendErrors: _.mapValues(_.keyBy(backendErrors, 'Id'), 'Text'),
    worldAreas: _.mapValues(_.keyBy(worldAreas, 'Id'), 'Name'),
  }
}
function transformAtlasNode(raw, {json}) {
  return {
    WorldAreasKey: truthy(raw.WorldAreasKey),
    ItemVisualIdentity: truthy(json["ItemVisualIdentity.dat"].data[raw.ItemVisualIdentityKey].DDSFile, raw),
    DDSFile: truthy(raw.DDSFile),
    AtlasRegion: truthy(json["AtlasRegions.dat"].data[raw.AtlasRegionsKey].Name, raw),
  }
}
function transformUniqueMap(raw, {json}) {
  return {
    WorldAreasKey: truthy(raw.WorldAreasKey),
    ItemVisualIdentity: truthy(json["ItemVisualIdentity.dat"].data[raw.ItemVisualIdentityKey].DDSFile, raw),
  }
}
function transformWorldArea(raw, {index, json, uniqueMaps, atlasNodes}) {
  return {
    Id: raw.Id,
    IsTown: raw.IsTown,
    IsHideout: raw.IsHideout,
    IsMapArea: raw.IsMapArea,
    IsUniqueMapArea: raw.IsUniqueMapArea,
    ItemVisualIdentity: (uniqueMaps[index] || atlasNodes[index] || {ItemVisualIdentity: null}).ItemVisualIdentity,
    RowID: index,
  }
}
function truthy(val, err) {
  if (!!val) return val
  // console.error(err)
  throw new Error("not truthy: "+err)
}
function rowsToObjects(header, rows) {
  return rows.map(r => _.zipObject(header, r))
}
function rowsFromObjects(header, rows) {
  return rows.map(r => header.map(k => r[k]))
}
function sheetFromObjects(rows) {
  const header = Object.keys(rows[0])
  return {
    header,
    data: rows.map(r => header.map(k => r[k]))
  }
}