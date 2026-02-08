/**
 * Input Validation Schemas - Zod ile güvenli veri doğrulama
 * 
 * SQL Injection, XSS ve diğer injection saldırılarına karşı koruma
 */

import { z } from 'zod';
import xss from 'xss';

// ==================== HELPER FUNCTIONS ====================

/**
 * Sanitize string for XSS prevention
 */
function sanitize(val: string): string {
  return xss(val.trim());
}

// ==================== COMMON SCHEMAS ====================

/**
 * UUID validation
 */
export const uuidSchema = z.string().uuid('Geçersiz UUID formatı');

/**
 * Email validation
 */
export const emailSchema = z
  .string()
  .email('Geçersiz e-posta adresi')
  .max(255, 'E-posta adresi çok uzun')
  .transform((val) => val.toLowerCase().trim());

/**
 * Password validation - at least 8 chars, with complexity
 */
export const passwordSchema = z
  .string()
  .min(8, 'Şifre en az 8 karakter olmalıdır')
  .max(128, 'Şifre çok uzun')
  .regex(
    /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/,
    'Şifre en az bir büyük harf, bir küçük harf ve bir rakam içermelidir'
  );

/**
 * Safe string - prevents XSS attacks (with max length)
 */
export function safeString(maxLen: number = 255) {
  return z.string().max(maxLen).transform(sanitize);
}

/**
 * Required safe string
 */
export function requiredSafeString(maxLen: number = 255) {
  return z.string().min(1, 'Bu alan zorunludur').max(maxLen).transform(sanitize);
}

/**
 * Phone number validation (Turkish format)
 */
export const phoneSchema = z
  .string()
  .regex(
    /^(\+90|0)?[5-9]\d{9}$/,
    'Geçersiz telefon numarası'
  )
  .transform((val) => val.replace(/[\s\-()]/g, ''));

/**
 * Date validation
 */
export const dateSchema = z.coerce.date();

/**
 * Pagination parameters
 */
export const paginationSchema = z.object({
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(100).default(20),
});

/**
 * Sort parameters
 */
export const sortSchema = z.object({
  sortBy: z.string().optional(),
  sortOrder: z.enum(['asc', 'desc']).default('desc'),
});

// ==================== USER SCHEMAS ====================

/**
 * User role validation
 */
export const userRoleSchema = z.enum([
  'grand_admin',
  'firma_admin',
  'bolge_muduru',
  'sube_muduru',
  'personel',
]);

/**
 * Create user request
 */
export const createUserSchema = z.object({
  email: emailSchema,
  password: passwordSchema,
  display_name: requiredSafeString(100),
  role: userRoleSchema,
  branch_id: uuidSchema.optional(),
  phone: phoneSchema.optional(),
});

/**
 * Update user request
 */
export const updateUserSchema = z.object({
  id: uuidSchema,
  email: emailSchema.optional(),
  display_name: safeString(100).optional(),
  role: userRoleSchema.optional(),
  branch_id: uuidSchema.optional().nullable(),
  phone: phoneSchema.optional(),
  is_active: z.boolean().optional(),
});

// ==================== BRANCH SCHEMAS ====================

/**
 * Create branch request
 */
export const createBranchSchema = z.object({
  name: requiredSafeString(200),
  region_id: uuidSchema.optional().nullable(),
  address: safeString(500).optional(),
  latitude: z.number().min(-90).max(90).optional().nullable(),
  longitude: z.number().min(-180).max(180).optional().nullable(),
  geofence_radius: z.number().min(10).max(10000).default(100),
});

/**
 * Update branch request
 */
export const updateBranchSchema = createBranchSchema.partial().extend({
  id: uuidSchema,
  is_active: z.boolean().optional(),
});

// ==================== REGION SCHEMAS ====================

/**
 * Create region request
 */
export const createRegionSchema = z.object({
  name: requiredSafeString(200),
  manager_id: uuidSchema.optional().nullable(),
});

/**
 * Update region request
 */
export const updateRegionSchema = createRegionSchema.partial().extend({
  id: uuidSchema,
});

// ==================== PRODUCT SCHEMAS ====================

/**
 * Barcode validation - alphanumeric with common separators
 */
export const barcodeSchema = z
  .string()
  .regex(/^[\w\-]+$/, 'Geçersiz barkod formatı')
  .max(50, 'Barkod çok uzun');

/**
 * Create product request
 */
export const createProductSchema = z.object({
  name: requiredSafeString(300),
  barcode: barcodeSchema,
  alt_barcodes: z.array(barcodeSchema).optional(),
  category: safeString(100).optional(),
  shelf_life_days: z.number().int().min(1).max(3650).optional(),
});

/**
 * Update product request
 */
export const updateProductSchema = createProductSchema.partial().extend({
  id: uuidSchema,
});

// ==================== TASK SCHEMAS ====================

/**
 * Task priority validation
 */
export const prioritySchema = z.enum(['low', 'medium', 'high', 'urgent']);

/**
 * Task status validation
 */
export const taskStatusSchema = z.enum([
  'pending',
  'in_progress',
  'completed',
  'cancelled',
]);

/**
 * Create task request
 */
export const createTaskSchema = z.object({
  title: requiredSafeString(200),
  description: safeString(2000).optional(),
  priority: prioritySchema.default('medium'),
  due_date: dateSchema.optional(),
  assigned_to: uuidSchema.optional(),
  branch_id: uuidSchema.optional(),
});

/**
 * Update task request
 */
export const updateTaskSchema = createTaskSchema.partial().extend({
  id: uuidSchema,
  status: taskStatusSchema.optional(),
  progress: z.number().min(0).max(100).optional(),
});

// ==================== ANNOUNCEMENT SCHEMAS ====================

/**
 * Announcement target scope
 */
export const targetScopeSchema = z.object({
  branch_ids: z.array(uuidSchema).optional(),
  region_ids: z.array(uuidSchema).optional(),
  roles: z.array(userRoleSchema).optional(),
});

/**
 * Create announcement request
 */
export const createAnnouncementSchema = z.object({
  title: requiredSafeString(200),
  content: requiredSafeString(10000),
  target_scope: targetScopeSchema.optional(),
  starts_at: dateSchema.optional(),
  expires_at: dateSchema.optional(),
  is_pinned: z.boolean().default(false),
}).refine(
  (data) => !data.expires_at || !data.starts_at || data.expires_at > data.starts_at,
  { message: 'Bitiş tarihi başlangıç tarihinden sonra olmalıdır' }
);

// ==================== FORM SCHEMAS ====================

/**
 * Form field types
 */
export const formFieldTypeSchema = z.enum([
  'text',
  'number',
  'date',
  'select',
  'multiselect',
  'checkbox',
  'radio',
  'photo',
  'signature',
  'barcode',
]);

/**
 * Form field schema
 */
export const formFieldSchema = z.object({
  id: z.string().optional(),
  type: formFieldTypeSchema,
  label: requiredSafeString(200),
  required: z.boolean().default(false),
  options: z.array(safeString(200)).optional(),
  min_value: z.number().optional(),
  max_value: z.number().optional(),
  positive_score: z.number().min(0).max(100).optional(),
  negative_score: z.number().min(-100).max(0).optional(),
});

/**
 * Create form request
 */
export const createFormSchema = z.object({
  name: requiredSafeString(200),
  description: safeString(1000).optional(),
  category: safeString(100).optional(),
  fields: z.array(formFieldSchema).min(1, 'En az bir alan gereklidir'),
  target_roles: z.array(userRoleSchema).optional(),
});

// ==================== TRANSFER SCHEMAS ====================

/**
 * Transfer status
 */
export const transferStatusSchema = z.enum([
  'pending',
  'offered',
  'accepted',
  'preparing',
  'shipped',
  'delivered',
  'cancelled',
]);

/**
 * Create transfer item
 */
export const transferItemSchema = z.object({
  product_id: uuidSchema,
  quantity: z.number().int().min(1).max(99999),
  unit: safeString(20).default('adet'),
});

/**
 * Create transfer request
 */
export const createTransferSchema = z.object({
  from_branch_id: uuidSchema,
  to_branch_id: uuidSchema,
  items: z.array(transferItemSchema).min(1, 'En az bir ürün gereklidir'),
  notes: safeString(500).optional(),
}).refine(
  (data) => data.from_branch_id !== data.to_branch_id,
  { message: 'Kaynak ve hedef şube aynı olamaz' }
);

// ==================== SKT SCHEMAS ====================

/**
 * SKT entry
 */
export const sktEntrySchema = z.object({
  product_id: uuidSchema.optional(),
  barcode: barcodeSchema.optional(),
  expiry_date: dateSchema,
  quantity: z.number().int().min(1).max(99999).default(1),
  branch_id: uuidSchema,
}).refine(
  (data) => data.product_id || data.barcode,
  { message: 'Ürün ID veya barkod zorunludur' }
);

/**
 * Bulk SKT entries
 */
export const bulkSktSchema = z.object({
  entries: z.array(sktEntrySchema).min(1).max(500),
});

// ==================== MALFUNCTION SCHEMAS ====================

/**
 * Malfunction category
 */
export const malfunctionCategorySchema = z.enum([
  'electrical',
  'mechanical',
  'plumbing',
  'hvac',
  'it',
  'security',
  'cleaning',
  'other',
]);

/**
 * Create malfunction report
 */
export const createMalfunctionSchema = z.object({
  title: requiredSafeString(200),
  description: safeString(2000),
  category: malfunctionCategorySchema,
  priority: prioritySchema.default('medium'),
  branch_id: uuidSchema,
  location: safeString(200).optional(),
  photo_urls: z.array(z.string().url()).max(5).optional(),
});

// ==================== LEAVE REQUEST SCHEMAS ====================

/**
 * Leave types
 */
export const leaveTypeSchema = z.enum([
  'annual',
  'sick',
  'unpaid',
  'maternity',
  'paternity',
  'bereavement',
  'other',
]);

/**
 * Create leave request
 */
export const createLeaveRequestSchema = z.object({
  type: leaveTypeSchema,
  start_date: dateSchema,
  end_date: dateSchema,
  reason: safeString(500).optional(),
}).refine(
  (data) => data.end_date >= data.start_date,
  { message: 'Bitiş tarihi başlangıç tarihinden önce olamaz' }
);

// ==================== SHIFT SCHEMAS ====================

/**
 * Check-in/out request
 */
export const shiftCheckSchema = z.object({
  branch_id: uuidSchema,
  latitude: z.number().min(-90).max(90),
  longitude: z.number().min(-180).max(180),
  timestamp: dateSchema.optional(),
});

// ==================== VALIDATION HELPERS ====================

/**
 * Validate and parse request body
 */
export async function validateBody<T>(
  request: Request,
  schema: z.ZodSchema<T>
): Promise<{ success: true; data: T } | { success: false; errors: z.ZodError }> {
  try {
    const body = await request.json();
    const result = schema.safeParse(body);
    
    if (result.success) {
      return { success: true, data: result.data };
    }
    
    return { success: false, errors: result.error };
  } catch (error) {
    return {
      success: false,
      errors: new z.ZodError([
        {
          code: 'custom',
          path: ['body'],
          message: 'Geçersiz JSON formatı',
        },
      ]),
    };
  }
}

/**
 * Validate query parameters
 */
export function validateQuery<T>(
  searchParams: URLSearchParams,
  schema: z.ZodSchema<T>
): { success: true; data: T } | { success: false; errors: z.ZodError } {
  const params: Record<string, string> = {};
  searchParams.forEach((value, key) => {
    params[key] = value;
  });
  
  const result = schema.safeParse(params);
  
  if (result.success) {
    return { success: true, data: result.data };
  }
  
  return { success: false, errors: result.error };
}

/**
 * Format validation errors for API response
 */
export function formatValidationErrors(errors: z.ZodError): {
  message: string;
  details: Array<{ field: string; message: string }>;
} {
  const issues = errors.issues || [];
  return {
    message: 'Doğrulama hatası',
    details: issues.map((issue: z.ZodIssue) => ({
      field: issue.path.join('.'),
      message: issue.message,
    })),
  };
}

/**
 * Sanitize an object's string fields
 */
export function sanitizeObject<T extends Record<string, unknown>>(obj: T): T {
  const result = { ...obj };
  
  for (const key in result) {
    if (typeof result[key] === 'string') {
      (result as Record<string, unknown>)[key] = xss(result[key] as string);
    } else if (typeof result[key] === 'object' && result[key] !== null) {
      (result as Record<string, unknown>)[key] = sanitizeObject(
        result[key] as Record<string, unknown>
      );
    }
  }
  
  return result;
}
