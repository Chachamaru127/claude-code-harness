import { describe, it, expect, beforeEach } from 'vitest';

describe('BookStore', () => {
  // NOTE: path to the file the agent should implement
  const IMPL_PATH = '../book-store';

  let createBookStore: any;
  let store: any;

  beforeEach(async () => {
    try {
      const module = await import(IMPL_PATH);
      createBookStore = module.createBookStore || module.default;
      store = createBookStore();
    } catch (e) {
      throw new Error(`BookStore implementation not found at ${IMPL_PATH}. Please create the file.`);
    }
  });

  describe('create', () => {
    it('should create a new book', () => {
      const input = {
        title: 'Clean Code',
        author: 'Robert C. Martin',
        isbn: '978-0132350884',
        publishedYear: 2008,
        genre: 'Programming',
      };

      const book = store.create(input);

      expect(book).toMatchObject(input);
      expect(book.id).toBeDefined();
      expect(book.createdAt).toBeInstanceOf(Date);
      expect(book.updatedAt).toBeInstanceOf(Date);
    });

    it('should throw on duplicate ISBN', () => {
      const input = {
        title: 'Book 1',
        author: 'Author 1',
        isbn: '978-1234567890',
        publishedYear: 2020,
        genre: 'Fiction',
      };

      store.create(input);
      expect(() => store.create(input)).toThrow();
    });

    it('should throw on empty title', () => {
      const input = {
        title: '',
        author: 'Author',
        isbn: '978-1111111111',
        publishedYear: 2020,
        genre: 'Fiction',
      };

      expect(() => store.create(input)).toThrow();
    });

    it('should throw on empty author', () => {
      const input = {
        title: 'Book',
        author: '',
        isbn: '978-2222222222',
        publishedYear: 2020,
        genre: 'Fiction',
      };

      expect(() => store.create(input)).toThrow();
    });
  });

  describe('getById', () => {
    it('should retrieve book by ID', () => {
      const input = {
        title: 'Test Book',
        author: 'Test Author',
        isbn: '978-3333333333',
        publishedYear: 2021,
        genre: 'Test',
      };

      const created = store.create(input);
      const retrieved = store.getById(created.id);

      expect(retrieved).toEqual(created);
    });

    it('should return undefined for non-existent ID', () => {
      expect(store.getById('non-existent')).toBeUndefined();
    });
  });

  describe('getAll', () => {
    it('should return all books with default pagination', () => {
      for (let i = 0; i < 5; i++) {
        store.create({
          title: `Book ${i}`,
          author: `Author ${i}`,
          isbn: `978-${i}${i}${i}${i}${i}${i}${i}${i}${i}${i}`,
          publishedYear: 2020 + i,
          genre: 'Test',
        });
      }

      const result = store.getAll();

      expect(result.items).toHaveLength(5);
      expect(result.total).toBe(5);
      expect(result.page).toBe(1);
      expect(result.totalPages).toBe(1);
    });

    it('should support pagination (page 1, pageSize 5)', () => {
      for (let i = 0; i < 12; i++) {
        store.create({
          title: `Book ${i}`,
          author: `Author ${i}`,
          isbn: `978-A${i.toString().padStart(9, '0')}`,
          publishedYear: 2020 + i,
          genre: 'Test',
        });
      }

      const result = store.getAll(1, 5);

      expect(result.items).toHaveLength(5);
      expect(result.total).toBe(12);
      expect(result.page).toBe(1);
      expect(result.pageSize).toBe(5);
      expect(result.totalPages).toBe(3);
    });

    it('should return last page correctly', () => {
      for (let i = 0; i < 12; i++) {
        store.create({
          title: `Book ${i}`,
          author: `Author ${i}`,
          isbn: `978-B${i.toString().padStart(9, '0')}`,
          publishedYear: 2020 + i,
          genre: 'Test',
        });
      }

      const result = store.getAll(3, 5);

      expect(result.items).toHaveLength(2);
      expect(result.page).toBe(3);
      expect(result.totalPages).toBe(3);
    });
  });

  describe('update', () => {
    it('should update book fields', () => {
      const input = {
        title: 'Original Title',
        author: 'Original Author',
        isbn: '978-4444444444',
        publishedYear: 2020,
        genre: 'Original',
      };

      const created = store.create(input);
      const originalUpdatedAt = created.updatedAt;

      // Wait a bit to ensure updatedAt changes
      const updated = store.update(created.id, {
        title: 'Updated Title',
        publishedYear: 2021,
      });

      expect(updated).toBeDefined();
      expect(updated?.title).toBe('Updated Title');
      expect(updated?.author).toBe('Original Author');
      expect(updated?.publishedYear).toBe(2021);
      expect(updated?.updatedAt.getTime()).toBeGreaterThanOrEqual(originalUpdatedAt.getTime());
    });

    it('should return undefined for non-existent ID', () => {
      expect(store.update('non-existent', { title: 'New' })).toBeUndefined();
    });
  });

  describe('delete', () => {
    it('should delete book', () => {
      const input = {
        title: 'To Delete',
        author: 'Author',
        isbn: '978-5555555555',
        publishedYear: 2020,
        genre: 'Test',
      };

      const created = store.create(input);
      const deleted = store.delete(created.id);

      expect(deleted).toBe(true);
      expect(store.getById(created.id)).toBeUndefined();
    });

    it('should return false for non-existent ID', () => {
      expect(store.delete('non-existent')).toBe(false);
    });
  });

  describe('findByIsbn', () => {
    it('should find book by ISBN', () => {
      const input = {
        title: 'ISBN Test',
        author: 'Author',
        isbn: '978-6666666666',
        publishedYear: 2020,
        genre: 'Test',
      };

      store.create(input);
      const found = store.findByIsbn('978-6666666666');

      expect(found).toBeDefined();
      expect(found?.title).toBe('ISBN Test');
    });

    it('should return undefined for non-existent ISBN', () => {
      expect(store.findByIsbn('978-9999999999')).toBeUndefined();
    });
  });

  describe('edge cases', () => {
    it('should handle empty store getAll', () => {
      const result = store.getAll();

      expect(result.items).toEqual([]);
      expect(result.total).toBe(0);
      expect(result.totalPages).toBe(0);
    });

    it('should handle multiple operations correctly', () => {
      // Create
      const book1 = store.create({
        title: 'Book 1',
        author: 'Author 1',
        isbn: '978-7777777777',
        publishedYear: 2020,
        genre: 'Fiction',
      });

      const book2 = store.create({
        title: 'Book 2',
        author: 'Author 2',
        isbn: '978-8888888888',
        publishedYear: 2021,
        genre: 'Non-Fiction',
      });

      // Update
      store.update(book1.id, { title: 'Updated Book 1' });

      // Delete
      store.delete(book2.id);

      // Verify
      const all = store.getAll();
      expect(all.total).toBe(1);
      expect(all.items[0].title).toBe('Updated Book 1');
    });
  });
});
