import { NextRequest, NextResponse } from 'next/server';
import { getSupabaseServerClient } from '@/lib/supabase/server';

interface BugReportFromRPC {
  report_id: string;
  report_tenant_id: string | null;
  report_tenant_name: string | null;
  report_user_id: string;
  report_user_name: string | null;
  report_user_email: string | null;
  report_title: string;
  report_description: string;
  report_device_info: Record<string, unknown> | null;
  report_app_version: string | null;
  report_status: string;
  report_priority: string;
  report_admin_notes: string | null;
  report_resolved_by: string | null;
  report_resolved_by_name: string | null;
  report_resolved_at: string | null;
  report_created_at: string;
}

export async function GET(request: NextRequest) {
  try {
    const supabase = await getSupabaseServerClient();
    
    // Get current user
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    // Get status filter
    const { searchParams } = new URL(request.url);
    const status = searchParams.get('status') || null;

    // Fetch bug reports
    const { data, error } = await supabase.rpc('get_bug_reports' as never, {
      p_status: status,
      p_limit: 100,
      p_offset: 0,
    } as never);

    if (error) {
      console.error('Bug reports fetch error:', error);
      return NextResponse.json({ error: error.message }, { status: 500 });
    }

    // Transform RPC response to frontend format
    const reports = ((data as BugReportFromRPC[]) || []).map((r) => ({
      id: r.report_id,
      tenant_id: r.report_tenant_id,
      tenant_name: r.report_tenant_name,
      user_id: r.report_user_id,
      user_name: r.report_user_name,
      user_email: r.report_user_email,
      title: r.report_title,
      description: r.report_description,
      device_info: r.report_device_info,
      app_version: r.report_app_version,
      status: r.report_status,
      priority: r.report_priority,
      admin_notes: r.report_admin_notes,
      resolved_by: r.report_resolved_by,
      resolved_by_name: r.report_resolved_by_name,
      resolved_at: r.report_resolved_at,
      created_at: r.report_created_at,
    }));

    return NextResponse.json({ reports });
  } catch (err) {
    console.error('Bug reports API error:', err);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}

export async function PATCH(request: NextRequest) {
  try {
    const supabase = await getSupabaseServerClient();
    
    // Get current user
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const body = await request.json();
    const { reportId, status, priority, adminNotes, sendMessage, message } = body;

    if (!reportId) {
      return NextResponse.json({ error: 'Report ID is required' }, { status: 400 });
    }

    // Mesaj gönderme işlemi
    if (sendMessage && message) {
      const { data, error } = await supabase.rpc('send_bug_report_message' as never, {
        p_report_id: reportId,
        p_message: message,
      } as never);

      if (error) {
        console.error('Bug report message error:', error);
        return NextResponse.json({ error: error.message }, { status: 500 });
      }

      return NextResponse.json({ success: data, messageSent: true });
    }

    // Update bug report
    const { data, error } = await supabase.rpc('update_bug_report' as never, {
      p_report_id: reportId,
      p_status: status || null,
      p_priority: priority || null,
      p_admin_notes: adminNotes || null,
    } as never);

    if (error) {
      console.error('Bug report update error:', error);
      return NextResponse.json({ error: error.message }, { status: 500 });
    }

    return NextResponse.json({ success: data });
  } catch (err) {
    console.error('Bug reports PATCH error:', err);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}
