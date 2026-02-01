// Announcement and Survey Types

export type AnnouncementType = 'announcement' | 'survey';

export type SurveyQuestionType = 
  | 'single_choice' 
  | 'multiple_choice' 
  | 'text' 
  | 'textarea'
  | 'rating' 
  | 'number'
  | 'yes_no';

export type TargetScope = 
  | 'all_branches'      // Firma Admin: Tüm bölgelerdeki tüm şubeler
  | 'all_regions'       // Firma Admin: Tüm bölgelerdeki tüm şubeler (alias)
  | 'selected_regions'  // Firma Admin: Seçili bölgeler (opsiyonel şube filtresi)
  | 'selected_branches' // Firma Admin/Bölge Müdürü: Seçili şubeler
  | 'my_branches'       // Bölge Müdürü: Kendi bölgesindeki tüm şubeler
  | 'my_branch'         // Şube Müdürü: Kendi şubesi
  | 'all_personnel'     // Şube Müdürü: Şubesindeki tüm personel
  | 'selected_personnel'// Şube Müdürü: Seçili personeller
  | 'region_managers_only';

export type UserRole = 
  | 'grand_admin' 
  | 'firma_admin' 
  | 'bolge_muduru' 
  | 'sube_muduru' 
  | 'personel';

export interface Announcement {
  id: string;
  tenant_id: string;
  title: string;
  content: string;
  summary?: string;
  cover_image_url?: string;
  type: AnnouncementType;
  target_scope: TargetScope;
  target_branches?: string[];
  target_regions?: string[];
  target_roles?: string[];
  managers_only: boolean;
  include_region_managers: boolean;
  published_by: string;
  created_by_role?: UserRole;
  published_at: string;
  expires_at?: string;
  active: boolean;
  pinned: boolean;
  pinned_at?: string;
  priority: number;
}

export interface AnnouncementWithStats extends Announcement {
  read_count?: number;
  response_count?: number;
  question_count?: number;
  publisher?: {
    id: string;
    name: string;
    role: string;
  };
}

export interface SurveyQuestion {
  id: string;
  announcement_id: string;
  question_text: string;
  question_type: SurveyQuestionType;
  options: string[];
  required: boolean;
  sort_order: number;
}

export interface SurveyResponse {
  id: string;
  announcement_id: string;
  user_id: string;
  submitted_at: string;
}

export interface SurveyAnswer {
  id: string;
  response_id: string;
  question_id: string;
  answer_text?: string;
  answer_options?: string[];
  answer_rating?: number;
  answer_boolean?: boolean;
}

// Form types for creating
export interface CreateAnnouncementForm {
  title: string;
  content: string;
  summary?: string;
  type: AnnouncementType;
  cover_image_url?: string;
  target_scope: TargetScope;
  target_branches: string[];
  target_regions: string[];
  target_users: string[];
  target_roles: string[];
  managers_only: boolean;
  include_region_managers: boolean;
  expires_at: string | null;
  pinned: boolean;
  priority: number;
}

export interface CreateSurveyQuestion {
  question_text: string;
  question_type: SurveyQuestionType;
  options: string[] | null;
  required: boolean;
  sort_order: number;
}

export interface CreateSurveyForm extends CreateAnnouncementForm {
  questions: CreateSurveyQuestion[];
}

// Survey results types (from RPC function)
export interface SurveyQuestionResult {
  question_id: string;
  question_text: string;
  question_type: SurveyQuestionType;
  required: boolean;
  options: string[] | null;
  answer_count: number;
  text_responses?: string[];
  statistics?: {
    // For rating
    average_rating?: number;
    rating_distribution?: Record<string, number>;
    // For choice
    choice_distribution?: Record<string, number>;
    // For boolean
    true_count?: number;
    false_count?: number;
    // For number
    min_number?: number;
    max_number?: number;
    average_number?: number;
  };
}

export interface SurveyResults {
  announcement: {
    id: string;
    title: string;
    content: string;
    published_at: string;
    expires_at?: string;
  };
  total_responses: number;
  questions: SurveyQuestionResult[];
}

// Branch & Region for targeting
export interface Branch {
  id: string;
  name: string;
  region_id?: string;
}

export interface Region {
  id: string;
  name: string;
}

export interface User {
  id: string;
  first_name: string;
  last_name: string;
  role: string;
  branch_id?: string;
}
