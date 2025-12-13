'use client';

import React, { createContext, useContext, useState, useEffect, ReactNode } from 'react';

export type ArticleSortField = 'created_at' | 'published_date' | 'like_count' | 'title';
export type ArticleSortOrder = 'asc' | 'desc';
export type ReadingStatus = 'all' | 'unread' | 'reading' | 'completed';

export interface ArticleFilters {
  searchQuery: string;
  readingStatus: ReadingStatus;
  isFavorite: boolean | undefined;
  sortField: ArticleSortField;
  sortOrder: ArticleSortOrder;
  selectedTags: string[];
  selectedDomain: string;
  showAdvancedFilters: boolean;
}

const DEFAULT_FILTERS: ArticleFilters = {
  searchQuery: '',
  readingStatus: 'all',
  isFavorite: undefined,
  sortField: 'created_at',
  sortOrder: 'desc',
  selectedTags: [],
  selectedDomain: '',
  showAdvancedFilters: false,
};

interface ArticleFiltersContextType {
  filters: ArticleFilters;
  setSearchQuery: (query: string) => void;
  setReadingStatus: (status: ReadingStatus) => void;
  setIsFavorite: (isFavorite: boolean | undefined) => void;
  setSortField: (field: ArticleSortField) => void;
  setSortOrder: (order: ArticleSortOrder) => void;
  setSelectedTags: (tags: string[]) => void;
  setSelectedDomain: (domain: string) => void;
  setShowAdvancedFilters: (show: boolean) => void;
  resetFilters: () => void;
}

const ArticleFiltersContext = createContext<ArticleFiltersContextType | undefined>(undefined);

const STORAGE_KEY = 'zuperreader_article_filters';

export function ArticleFiltersProvider({ children }: { children: ReactNode }) {
  const [filters, setFilters] = useState<ArticleFilters>(DEFAULT_FILTERS);
  const [isInitialized, setIsInitialized] = useState(false);

  // Load filters from localStorage on mount
  useEffect(() => {
    try {
      const stored = localStorage.getItem(STORAGE_KEY);
      if (stored) {
        const parsedFilters = JSON.parse(stored);
        setFilters({ ...DEFAULT_FILTERS, ...parsedFilters });
      }
    } catch (error) {
      console.error('Error loading article filters from localStorage:', error);
    } finally {
      setIsInitialized(true);
    }
  }, []);

  // Save filters to localStorage whenever they change
  useEffect(() => {
    if (!isInitialized) return;

    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(filters));
    } catch (error) {
      console.error('Error saving article filters to localStorage:', error);
    }
  }, [filters, isInitialized]);

  const setSearchQuery = (query: string) => {
    setFilters(prev => ({ ...prev, searchQuery: query }));
  };

  const setReadingStatus = (status: ReadingStatus) => {
    setFilters(prev => ({ ...prev, readingStatus: status }));
  };

  const setIsFavorite = (isFavorite: boolean | undefined) => {
    setFilters(prev => ({ ...prev, isFavorite }));
  };

  const setSortField = (field: ArticleSortField) => {
    setFilters(prev => ({ ...prev, sortField: field }));
  };

  const setSortOrder = (order: ArticleSortOrder) => {
    setFilters(prev => ({ ...prev, sortOrder: order }));
  };

  const setSelectedTags = (tags: string[]) => {
    setFilters(prev => ({ ...prev, selectedTags: tags }));
  };

  const setSelectedDomain = (domain: string) => {
    setFilters(prev => ({ ...prev, selectedDomain: domain }));
  };

  const setShowAdvancedFilters = (show: boolean) => {
    setFilters(prev => ({ ...prev, showAdvancedFilters: show }));
  };

  const resetFilters = () => {
    setFilters(DEFAULT_FILTERS);
  };

  return (
    <ArticleFiltersContext.Provider
      value={{
        filters,
        setSearchQuery,
        setReadingStatus,
        setIsFavorite,
        setSortField,
        setSortOrder,
        setSelectedTags,
        setSelectedDomain,
        setShowAdvancedFilters,
        resetFilters,
      }}
    >
      {children}
    </ArticleFiltersContext.Provider>
  );
}

export function useArticleFilters() {
  const context = useContext(ArticleFiltersContext);
  if (!context) {
    throw new Error('useArticleFilters must be used within ArticleFiltersProvider');
  }
  return context;
}
