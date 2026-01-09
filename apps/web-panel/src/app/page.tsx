import type { Route } from "next";
import { redirect } from "next/navigation";

export default function Page() {
	redirect("/overview" as Route);
}
