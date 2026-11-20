import { logAdminActivity } from '../../../utils/activityLogger.js'
import { SectionsRepository } from './sections.repository.js'

const repo = new SectionsRepository()

export class SectionsService {
  async getByTabId(tabId, audience = 'B2C') {
    return repo.findByTabId(tabId, audience)
  }

  async getById(id) {
    return repo.findById(id)
  }

  async create(tabId, data, adminId, ip) {
    const tab = await repo.findTabById(tabId)
    if (!tab) return null

    const section = await repo.create(tabId, {
      ...data,
      config: data.config || {},
    })

    const createdSection = await repo.findById(section.id)

    logAdminActivity(adminId, 'CREATE_SECTION', 'section_manifest', section.id, null, null, ip)
    return createdSection
  }

  async update(id, data, adminId, ip) {
    const existing = await repo.findById(id)
    if (!existing) return null

    const nextData = { ...data }
    if (data.config !== undefined) {
      nextData.config = mergeSectionConfig(existing.config || {}, data.config)
    }

    const section = await repo.update(id, nextData)
    if (!section) return null

    logAdminActivity(adminId, 'UPDATE_SECTION', 'section_manifest', id, null, null, ip)
    return repo.findById(id)
  }

  async updateMerchBinding(id, binding, adminId, ip) {
    const existing = await repo.findById(id)
    if (!existing) return null

    const section = await repo.updateMerchBinding(id, binding)
    if (!section) return null

    logAdminActivity(adminId, 'UPDATE_SECTION_MERCH', 'section_manifest', id, null, null, ip)
    return repo.findById(id)
  }

  async remove(id, adminId, ip) {
    const section = await repo.delete(id)
    if (!section) return null

    logAdminActivity(adminId, 'DELETE_SECTION', 'section_manifest', id, null, null, ip)
    return section
  }

  async reorder(tabId, orderedIds, audience, adminId, ip) {
    const sections = await repo.reorder(tabId, orderedIds, audience)

    logAdminActivity(adminId, 'REORDER_SECTIONS', 'section_manifest', tabId, null, null, ip)
    return sections
  }

  async duplicate(id, adminId, ip) {
    const section = await repo.duplicate(id)
    if (!section) return null

    const duplicatedSection = await repo.findById(section.id)

    logAdminActivity(adminId, 'DUPLICATE_SECTION', 'section_manifest', section.id, null, null, ip)
    return duplicatedSection
  }

  /**
   * "Copy B2C to B2B" — bootstraps a tab's B2B section list from its
   * current B2C one, mirroring the same bulk-copy action already shipped
   * for themes (dashboard "Copy B2C to B2B" button on the Themes list).
   * Refuses to overwrite an existing B2B section list.
   */
  async copyToAudience(tabId, fromAudience, toAudience, adminId, ip) {
    const tab = await repo.findTabById(tabId)
    if (!tab) return null

    const result = await repo.copySections(tabId, fromAudience, toAudience)

    if (result.copied > 0) {
      logAdminActivity(
        adminId,
        'COPY_SECTIONS',
        'section_manifest',
        tabId,
        null,
        { fromAudience, toAudience, copied: result.copied },
        ip
      )
    }

    return result
  }

  async saveSnapshot(tabId, audience, adminId) {
    const sections = await repo.findByTabId(tabId, audience)
    return repo.createVersion(tabId, sections, adminId, { audience })
  }

  async getVersions(tabId, audience = 'B2C') {
    return repo.getVersions(tabId, audience)
  }

  async rollbackToVersion(tabId, versionId, adminId, ip) {
    const version = await repo.findVersionById(tabId, versionId)
    if (!version) return null

    const sections = await repo.restoreSnapshot(tabId, version.snapshot, version.audience)

    logAdminActivity(adminId, 'ROLLBACK_SECTIONS', 'section_manifest', tabId, null, null, ip)
    return sections
  }


}

function mergeSectionConfig(currentValue, nextValue) {
  if (Array.isArray(nextValue)) {
    return nextValue
  }

  if (isPlainObject(currentValue) && isPlainObject(nextValue)) {
    const merged = { ...currentValue }
    for (const [key, value] of Object.entries(nextValue)) {
      merged[key] = mergeSectionConfig(currentValue[key], value)
    }
    return merged
  }

  return nextValue
}

function isPlainObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value)
}
