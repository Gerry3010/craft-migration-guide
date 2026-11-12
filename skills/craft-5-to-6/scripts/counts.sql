-- Content inventory for a Craft 5 or Craft 6 database (MySQL/MariaDB).
-- Run before and after the upgrade and diff the two outputs:
--   mysql -N db < counts.sql > counts-before.txt
-- Expected differences after the upgrade: element type class names
-- (craft\elements\Entry -> CraftCms\Cms\Entry\Elements\Entry) and fewer
-- `relations` rows (Craft 6 drops relation rows of Link fields).

-- Entries per section: canonical, drafts, revisions (soft-deleted excluded)
SELECT CONCAT('section:', COALESCE(s.handle, '(nested)')) k,
       SUM(el.draftId IS NULL AND el.revisionId IS NULL) canonical,
       SUM(el.draftId IS NOT NULL) drafts,
       SUM(el.revisionId IS NOT NULL) revisions
FROM entries e
JOIN elements el ON el.id = e.id
LEFT JOIN sections s ON s.id = e.sectionId
WHERE el.dateDeleted IS NULL
GROUP BY s.handle
ORDER BY k;

-- Nested entries per field (Matrix and other nested-entry fields)
SELECT CONCAT('nested-field:', f.handle) k, COUNT(*) n
FROM entries e
JOIN elements el ON el.id = e.id
JOIN fields f ON f.id = e.fieldId
WHERE el.dateDeleted IS NULL AND el.draftId IS NULL AND el.revisionId IS NULL
GROUP BY f.handle
ORDER BY k;

-- Elements per type
SELECT CONCAT('type:', el.type) k, COUNT(*) n
FROM elements el
WHERE el.dateDeleted IS NULL AND el.draftId IS NULL AND el.revisionId IS NULL
GROUP BY el.type
ORDER BY k;

-- Assets per volume
SELECT CONCAT('volume:', v.handle) k, COUNT(*) n
FROM assets a
JOIN elements el ON el.id = a.id
JOIN volumes v ON v.id = a.volumeId
WHERE el.dateDeleted IS NULL
GROUP BY v.handle
ORDER BY k;

-- Structure
SELECT 'sections' k, COUNT(*) n FROM sections WHERE dateDeleted IS NULL
UNION ALL SELECT 'entrytypes', COUNT(*) FROM entrytypes WHERE dateDeleted IS NULL
UNION ALL SELECT 'fields', COUNT(*) FROM fields WHERE dateDeleted IS NULL
UNION ALL SELECT 'volumes', COUNT(*) FROM volumes WHERE dateDeleted IS NULL
UNION ALL SELECT 'users', COUNT(*) FROM users
UNION ALL SELECT 'relations', COUNT(*) FROM relations
UNION ALL SELECT 'elements_sites', COUNT(*) FROM elements_sites;

-- Checksum over title, slug, URI, field content and status of canonical elements
SELECT 'content-checksum' k,
       SUM(CRC32(CONCAT_WS('|', es.elementId, es.siteId, es.title, es.slug, es.uri, es.content, es.enabled))) n
FROM elements_sites es
JOIN elements el ON el.id = es.elementId
WHERE el.dateDeleted IS NULL AND el.draftId IS NULL AND el.revisionId IS NULL;
