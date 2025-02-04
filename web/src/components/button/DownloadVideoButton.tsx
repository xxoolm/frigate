import { Button } from "@/components/ui/button";
import { toast } from "sonner";
import { FaDownload } from "react-icons/fa";
import { formatUnixTimestampToDateTime } from "@/utils/dateUtil";
import { cn } from "@/lib/utils";

type DownloadVideoButtonProps = {
  source: string;
  camera: string;
  startTime: number;
  className?: string;
};

export function DownloadVideoButton({
  source,
  camera,
  startTime,
  className,
}: DownloadVideoButtonProps) {
  const formattedDate = formatUnixTimestampToDateTime(startTime, {
    strftime_fmt: "%D-%T",
    time_style: "medium",
    date_style: "medium",
  });
  const filename = `${camera}_${formattedDate}.mp4`;

  const handleDownloadStart = () => {
    toast.success("Your review item video has started downloading.", {
      position: "top-center",
    });
  };

  return (
    <div className="flex justify-center">
      <Button
        asChild
        className="flex items-center gap-2"
        size="sm"
        aria-label="Download Video"
      >
        <a href={source} download={filename} onClick={handleDownloadStart}>
          <FaDownload
            className={cn("size-4 text-secondary-foreground", className)}
          />
        </a>
      </Button>
    </div>
  );
}
